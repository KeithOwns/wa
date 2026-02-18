#Requires -RunAsAdministrator
# file: Install_RequiredApps.ps1
param(
  [ValidateSet('Desktop', 'Laptop', 'Auto')]
  [string]$DeviceType = 'Auto'
)

# --- SHARED RESOURCES ---
. "$PSScriptRoot\Shared_UI_Functions.ps1"

# --- CHECK ADMIN ---
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-LeftAligned "$FGRed$Char_RedCross Administrator privileges required.$Reset"
  Write-LeftAligned "$FGGray Right-click and 'Run as Administrator'.$Reset"
  Start-Sleep -Seconds 2
  exit
}

# --- HEADER ---
Write-Header "APPLICATION INSTALLER"

# --- [NEW] CONFIGURE DEFENDER SETTINGS ---
Write-Host ""
Write-LeftAligned "Attempting to disable 'Controlled Folder Access'..."

try {
  # Disable Controlled Folder Access
  Set-MpPreference -EnableControlledFolderAccess Disabled -ErrorAction Stop
    
  # Verify the setting
  $newPrefs = Get-MpPreference
  if ($newPrefs.EnableControlledFolderAccess -eq 0) {
    Write-LeftAligned "$FGGreen$Char_HeavyCheck Controlled Folder Access disabled.$Reset"
  }
  else {
    Write-LeftAligned "$FGRed$Char_RedCross Failed to disable Controlled Folder Access.$Reset"
    Write-LeftAligned "$FGDarkYellow State: $($newPrefs.EnableControlledFolderAccess) (Likely GPO Managed)$Reset"
  }
}
catch {
  Write-LeftAligned "$FGRed$Char_Warn Error disabling Controlled Folder Access:$Reset"
  Write-LeftAligned "$FGRed   $($_.Exception.Message)$Reset"
}
Write-Boundary $FGDarkGray
# --- [END NEW] ---

# --- LOAD CONFIGURATION ---
$JsonPath = "$PSScriptRoot\Install_RequiredApps-WinAuto.json"
if (-not (Test-Path $JsonPath)) {
  Write-LeftAligned "$FGRed$Char_RedCross Config file missing: $JsonPath$Reset"
  exit
}

try {
  $Config = Get-Content $JsonPath -Raw | ConvertFrom-Json
  $BaseApps = $Config.BaseApps
  $LaptopApps = $Config.LaptopApps
}
catch {
  Write-LeftAligned "$FGRed$Char_RedCross Failed to parse JSON config.$Reset"
  exit
}

# --- SETTINGS ---
$MinWingetVersion = [version]'1.5.0'
$StartTime = Get-Date
$TranscriptLogPath = Join-Path -Path ([Environment]::GetFolderPath('Desktop')) -ChildPath ("WinAuto-AppInstall-Transcript-{0:yyyyMMdd-HHmmss}.txt" -f $StartTime)
$SummaryLogPath = Join-Path -Path ([Environment]::GetFolderPath('Desktop')) -ChildPath ("WinAuto-AppInstall-Summary-{0:yyyyMMdd-HHmmss}.txt" -f $StartTime)
Start-Transcript -Path $TranscriptLogPath -Append | Out-Null
$Summary = [System.Collections.Generic.List[object]]::new()
$SoftSuccessCodes = @(0, 3010, -2145124332, 0x8024001E, 0x8024200B)
$ScriptExitCode = 0

# --- FUNCTIONS ---
function Add-Tls {
  if ([Net.ServicePointManager]::SecurityProtocol -notmatch 'Tls12|Tls13') {
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13 }
    catch {
      Write-LeftAligned "$FGDarkYellow Could not enable TLS 1.3, using TLS 1.2 only.$Reset"
      [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    }
  }
}

function Test-AppConfiguration {
  [CmdletBinding()]
  param([Parameter(Mandatory)][hashtable]$App)
  $errors = @()
  if (-not $App.ContainsKey('AppName') -or [string]::IsNullOrWhiteSpace($App.AppName)) { $errors += "Missing required field: AppName" }
  if ($App.ContainsKey('IsPrerequisite') -and $App.IsPrerequisite) { return $true }
  if (-not $App.ContainsKey('Type')) { $errors += "Missing required field: Type for app '$($App.AppName)'" }
  if ($App.Type -eq 'WINGET' -and -not $App.ContainsKey('WingetId')) { $errors += "WINGET type requires WingetId for app '$($App.AppName)'" }
  if (($App.Type -eq 'MSI' -or $App.Type -eq 'EXE') -and -not ($App.ContainsKey('Url') -or $App.ContainsKey('Urls') -or $App.ContainsKey('InstallerPath'))) {
    $errors += "$($App.Type) type requires Url, Urls, or InstallerPath for app '$($App.AppName)'"
  }
  if ($errors.Count -gt 0) { Write-Log "Configuration errors: $($errors -join ", ")" -Level ERROR; return $false }
  return $true
}

function Get-File {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$Url, [Parameter(Mandatory)][string]$Out)
  Add-Tls
  Write-LeftAligned "$FGGray Downloading from: $Url$Reset"
  for ($i = 1; $i -le 3; $i++) {
    try {
      $ProgressPreference = 'SilentlyContinue'
      Invoke-WebRequest -Uri $Url -OutFile $Out -UseBasicParsing -ErrorAction Stop
      $ProgressPreference = 'Continue'
      if (Test-Path $Out) {
        $fileSize = (Get-Item $Out).Length
        Write-LeftAligned "$FGGray Download complete: $([math]::Round($fileSize/1MB,2)) MB$Reset"
      }
      return
    }
    catch {
      if ($i -lt 3) { Write-LeftAligned "$FGDarkYellow Retry $i/3 in $($i*5)s...$Reset"; Start-Sleep -Seconds ($i * 5) }
      else { throw "Download failed: $($_.Exception.Message)" }
    }
  }
}

function Get-MsiUrlFromLanding {
  param([Parameter(Mandatory)][string]$LandingUrl)
  Add-Tls
  $html = Invoke-WebRequest -Uri $LandingUrl -UseBasicParsing -ErrorAction Stop
  $msi = ($html.Links | Where-Object { $_.href -match '\.msi($|\?)' } | Select-Object -First 1).href
  if (-not $msi) { throw "No MSI link found at: $LandingUrl" }
  if ($msi -notmatch '^https?://') {
    $uri = [Uri]$LandingUrl; $base = "$($uri.Scheme)://$($uri.Host)"
    $msi = if ($msi.StartsWith('/')) { "$base$msi" } else { "$base/$msi" }
  }
  return $msi
}

function Ensure-WingetSources {
  try {
    Write-LeftAligned "$FGDarkYellow Checking Winget sources...$Reset"
    $null = Start-Process -FilePath "winget.exe" -ArgumentList @("source", "update", "--disable-interactivity") -Wait -PassThru -ErrorAction SilentlyContinue
    $en = Start-Process -FilePath "winget.exe" -ArgumentList @("source", "enable", "msstore", "--disable-interactivity") -Wait -PassThru -ErrorAction SilentlyContinue
    if ($en -and $en.ExitCode -ne 0) {
      Start-Process -FilePath "winget.exe" -ArgumentList @("source", "add", "-n", "msstore", "-a", "https://storeedgefd.dsx.mp.microsoft.com/v9.0", "--disable-interactivity") -Wait -ErrorAction SilentlyContinue | Out-Null
    }
    Write-LeftAligned "$FGGreen$Char_HeavyCheck Winget sources ready.$Reset"
  }
  catch { Write-LeftAligned "$FGRed Winget source prep failed: $($_.Exception.Message)$Reset" }
}

function Assert-WingetVersion {
  param([Parameter(Mandatory)][version]$Minimum)
  $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
  if (-not $winget) { Write-LeftAligned "$FGRed$Char_FailureX Winget not installed.$Reset"; return $false }
  try { $raw = & winget --version 2>$null; $verText = ($raw | Select-Object -First 1).ToString().Trim().TrimStart('v', 'V'); $ver = [version]$verText }
  catch { Write-LeftAligned "$FGRed$Char_FailureX Unable to determine winget version.$Reset"; return $false }
  if ($ver -lt $Minimum) { Write-LeftAligned "$FGRed$Char_FailureX Winget $verText detected. Need $Minimum+.$Reset"; return $false }
  Write-LeftAligned "$FGGreen$Char_HeavyCheck Winget $verText OK.$Reset"
  return $true
}

function Test-AppInstalled {
  [CmdletBinding()]
  param([Parameter(Mandatory)][hashtable]$App)

  if ($App.ContainsKey('CheckMethod') -and $App.CheckMethod -eq 'Appx') {
    $name = if ($App.ContainsKey('AppxName') -and $App.AppxName) { $App.AppxName } elseif ($App.ContainsKey('MatchName') -and $App.MatchName) { $App.MatchName } else { $App.AppName }
    $pkg = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq $name -or $_.PackageFamilyName -like "$name*" -or $_.Name -like "$name*" } | Select-Object -First 1
    return [bool]$pkg
  }

  if ($App.ContainsKey('CheckMethod') -and $App.CheckMethod -eq 'File') {
    $path = if ($App.ContainsKey('FilePath')) { $App['FilePath'] } else { $null }
    return ([bool]$path -and (Test-Path -Path $path))
  }

  $scope = if ($App.ContainsKey('RegistryScope')) { $App.RegistryScope } else { 'Machine' }
  $roots = @()
  if ($scope -eq 'Machine' -or $scope -eq 'All') {
    $roots += "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
    $roots += "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
  }
  if ($scope -eq 'User' -or $scope -eq 'All') {
    $roots += "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
    $roots += "HKCU:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
  }

  $pattern = if ($App.ContainsKey('MatchName')) { $App.MatchName } else { $App.AppName }
  foreach ($r in $roots) {
    if (-not (Test-Path $r)) { continue }
    foreach ($k in (Get-ChildItem $r -ErrorAction SilentlyContinue)) {
      $dn = $k.GetValue('DisplayName', $null)
      if ($dn -and ($dn -like $pattern)) { return $true }
    }
  }
  return $false
}

function Install-WithWingetRetry {
  param([Parameter(Mandatory)][hashtable]$App)
  $base = @("install", "--id", $App.WingetId, "-e", "--accept-package-agreements", "--accept-source-agreements", "--silent", "--disable-interactivity")
  if ($App.ContainsKey('Source') -and $App.Source) { $base += @("--source", $App.Source) }

  # Attempt 1
  $args1 = @($base)
  if ($App.ContainsKey('WingetScope') -and $App.WingetScope) { $args1 += @("--scope", $App.WingetScope) }
  $p1 = Start-Process -FilePath "winget.exe" -ArgumentList $args1 -Wait -PassThru -ErrorAction SilentlyContinue
  $c1 = if ($null -ne $p1) { $p1.ExitCode } else { 0 }
  if ($c1 -eq 0) { return 0 }

  # Attempt 2
  try { Start-Process winget.exe -ArgumentList @("source", "update", "--disable-interactivity") -Wait -ErrorAction SilentlyContinue | Out-Null } catch {}
  $alt = if ($App.ContainsKey('WingetScope') -and $App.WingetScope -eq 'Machine') { 'User' } else { 'Machine' }
  $args2 = @($base) + @("--scope", $alt)
  $p2 = Start-Process -FilePath "winget.exe" -ArgumentList $args2 -Wait -PassThru -ErrorAction SilentlyContinue
  $c2 = if ($null -ne $p2) { $p2.ExitCode } else { 0 }
  if ($c2 -eq 0) { return 0 }

  Write-LeftAligned "$FGDarkYellow Winget failed. Codes: $c1, $c2.$Reset"
  return $c2
}

function Wait-UntilDetected {
  param([Parameter(Mandatory)][hashtable]$App, [int]$TimeoutSec = 150, [int]$IntervalSec = 5)
  $deadline = (Get-Date).AddSeconds($TimeoutSec)
  do {
    if (Test-AppInstalled -App $App) { return $true }
    Start-Sleep -Seconds $IntervalSec
  } while ((Get-Date) -lt $deadline)
  return $false
}

function Invoke-GenericInstall {
  [CmdletBinding()]
  param([Parameter(Mandatory)][hashtable]$App)
  $AppName = $App.AppName
  $InstallerType = $App.Type
  Write-Host ""
  Write-LeftAligned "$FGDarkCyan Installing '$AppName' ($InstallerType)...$Reset"

  if ($App.ContainsKey('PreInstallDelay') -and $App.PreInstallDelay -gt 0) {
    Write-LeftAligned "$FGDarkYellow Waiting $($App.PreInstallDelay)s...$Reset"
    Start-Sleep -Seconds $App.PreInstallDelay
  }

  $tmp = $null; $exit = $null

  try {
    switch ($InstallerType) {
      "MSI" {
        $installerFilePath = $null
        if ($App.ContainsKey('InstallerPath') -and (Test-Path -Path $App.InstallerPath)) {
          $installerFilePath = $App.InstallerPath
          Write-LeftAligned "$FGGray Using local installer.$Reset"
        }
        else {
          $urls = @()
          if ($App.ContainsKey('Urls')) { $urls = @($App.Urls) } elseif ($App.ContainsKey('Url')) { $urls = @($App.Url) }
          
          if ($urls.Count -eq 0) { throw "No URL(s) specified for MSI." }
          $resolvedUrl = $null
          foreach ($u in $urls) {
            try {
              if ($u -match '\.msi($|\?)|//aka\.ms/') { $resolvedUrl = $u } else { $resolvedUrl = Get-MsiUrlFromLanding -LandingUrl $u }
              break
            }
            catch { continue }
          }
          if (-not $resolvedUrl) { throw "Could not resolve valid MSI URL." }
          $InstallerFileName = if ($App.ContainsKey('OutFileName')) { $App.OutFileName } else { [IO.Path]::GetFileName(([Uri]$resolvedUrl).AbsolutePath) }
          if ([string]::IsNullOrWhiteSpace($InstallerFileName)) { $InstallerFileName = "$($App.AppName.Replace(' ','-'))-installer.msi" }
          $installerFilePath = Join-Path -Path $env:TEMP -ChildPath $InstallerFileName
          Get-File -Url $resolvedUrl -Out $installerFilePath
          $tmp = $installerFilePath
        }
        $msiArgs = "/i `"$installerFilePath`" /qn /norestart"
        if ($App.ContainsKey('MsiParams') -and $App.MsiParams) { $msiArgs += " $($App.MsiParams)" }
        $p = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru -ErrorAction Stop
        $exit = $p.ExitCode
      }
      "EXE" {
        $installerFilePath = $null
        if ($App.ContainsKey('InstallerPath') -and (Test-Path -Path $App.InstallerPath)) {
          $installerFilePath = $App.InstallerPath
        }
        elseif ($App.ContainsKey('Url')) {
          $InstallerFileName = if ($App.ContainsKey('OutFileName')) { $App.OutFileName } else { [IO.Path]::GetFileName(([Uri]$App.Url).AbsolutePath) }
          if ([string]::IsNullOrWhiteSpace($InstallerFileName) -or $InstallerFileName -eq "files") { $InstallerFileName = "$($App.AppName.Replace(' ','-'))-installer.exe" }
          $installerFilePath = Join-Path -Path $env:TEMP -ChildPath $InstallerFileName
          Get-File -Url $App.Url -Out $installerFilePath
          $tmp = $installerFilePath
        }
        else { throw "No valid InstallerPath or Url found." }
        $args = if ($App.ContainsKey('SilentArgs')) { $App.SilentArgs } else { "/quiet /norestart" }
        $p = Start-Process -FilePath $installerFilePath -ArgumentList $args -Wait -PassThru -ErrorAction Stop
        $exit = $p.ExitCode
      }
      "WINGET" {
        $exit = Install-WithWingetRetry -App $App
      }
      "BUILTIN" {
        Write-LeftAligned "$FGGreen$Char_HeavyCheck Built-in.$Reset"
        $exit = 0
      }
      Default { throw "Unknown Type: $InstallerType" }
    }

    if ($null -eq $exit) { $exit = 0 }
    if ($SoftSuccessCodes -notcontains $exit) { throw "Exit Code: $exit" }
  }
  catch {
    Write-LeftAligned "$FGRed$Char_FailureX Installation failed: $($_.Exception.Message)$Reset"
    $finalExitCode = if ($null -ne $exit) { $exit } else { -1 }
    $Summary.Add([pscustomobject]@{ AppName = $AppName; Type = $InstallerType; Exit = $finalExitCode; Present = $false; Time = Get-Date })
    $global:ScriptExitCode = 1
    return
  }
  finally { if ($tmp -and (Test-Path $tmp)) { Remove-Item -Path $tmp -Force -ErrorAction SilentlyContinue } }

  $isUserCtx = (($App.ContainsKey('RegistryScope') -and $App.RegistryScope -eq 'User') -or (($App.ContainsKey('CheckMethod') -and $App.CheckMethod -eq 'Appx') -and ($App.ContainsKey('Source') -and $App.Source -eq 'msstore'))) -and ($App.WingetScope -ne 'Machine')

  $present = $false
  if ($isUserCtx) {
    Write-LeftAligned "$FGDarkYellow User-context. Verification deferred.$Reset"
    $present = $true
  }
  else {
    $present = Wait-UntilDetected -App $App -TimeoutSec 150 -IntervalSec 5
    if ($present) { Write-LeftAligned "$FGGreen$Char_HeavyCheck Installed.$Reset" }
    else { Write-LeftAligned "$FGDarkYellow$Char_Warn Verification timeout.$Reset" }
  }

  $Summary.Add([pscustomobject]@{ AppName = $AppName; Type = $InstallerType; Exit = $exit; Present = [bool]$present; Time = Get-Date })
}

# --- DEVICE TYPE DETERMINATION ---
$IsDesktop = $false
if ($DeviceType -eq 'Desktop') { $IsDesktop = $true }
elseif ($DeviceType -eq 'Laptop') { $IsDesktop = $false }
else {
  try {
    $chassis = (Get-CimInstance -ClassName Win32_SystemEnclosure -ErrorAction SilentlyContinue).ChassisTypes
    if ($chassis -and ($chassis -contains 3 -or $chassis -contains 4 -or $chassis -contains 5 -or $chassis -contains 6 -or $chassis -contains 7 -or $chassis -contains 15 -or $chassis -contains 23 -or $chassis -contains 31)) { $IsDesktop = $true }
  }
  catch {}
  Write-LeftAligned "$FGGray Detected: $(if($IsDesktop){'Desktop'}else{'Laptop'})$Reset"
}

# Compose final app list
$RequiredApps = [System.Collections.Generic.List[Object]]::new()
if ($BaseApps) { $RequiredApps.AddRange($BaseApps) }
if (-not $IsDesktop -and $LaptopApps) {
  $RequiredApps.AddRange($LaptopApps)
  Write-LeftAligned "$FGGray Included Laptop specific apps.$Reset"
}

# --- MAIN SCRIPT BODY ---

Write-Host ""
Write-LeftAligned "Validating configuration..."
$configValid = $true
foreach ($app in $RequiredApps) { if (-not (Test-AppConfiguration -App $app)) { $configValid = $false } }
if (-not $configValid) { Write-LeftAligned "$FGRed$Char_FailureX Invalid Config.$Reset"; exit }
Write-LeftAligned "$FGGreen$Char_HeavyCheck Configuration valid.$Reset"

# Separate apps
$PrerequisiteApps = $RequiredApps | Where-Object { $_.ContainsKey('IsPrerequisite') -and $_.IsPrerequisite }
$StandardApps = $RequiredApps | Where-Object { -not ($_.ContainsKey('IsPrerequisite') -and $_.IsPrerequisite) }

# --- GUIDED PREREQUISITE CHECK ---
if ($PrerequisiteApps.Count -gt 0) {
  while ($true) {
    Write-Host ""
    Write-BodyTitle "SECURITY PREREQUISITES"
    $MissingPrereqs = [System.collections.Generic.List[object]]::new()

    foreach ($app in $PrerequisiteApps) {
      if (-not (Test-AppInstalled -App $app)) { $MissingPrereqs.Add($app) }
      else { Write-LeftAligned "$FGDarkGreen$Char_BallotCheck $($app.AppName): Found$Reset" }
    }

    if ($MissingPrereqs.Count -gt 0) {
      Write-LeftAligned "$FGDarkYellow Missing Prerequisites:$Reset"
      foreach ($app in $MissingPrereqs) {
        Write-LeftAligned "$FGRed$Char_FailureX $($app.AppName)$Reset"
      }
      Invoke-AnimatedPause "RE-CHECK"
    }
    else {
      Write-LeftAligned "$FGGreen$Char_HeavyCheck All prerequisites met.$Reset"
      Write-Boundary $FGDarkGray
      break
    }
  }
}

# --- STANDARD INSTALLATION ---
if (-not (Assert-WingetVersion -Minimum $MinWingetVersion)) { exit }
Ensure-WingetSources

Write-Host ""
Write-LeftAligned "Checking application status..."
$AppsToInstall = @()
$AlreadyPresentApps = [System.Collections.Generic.List[string]]::new()
foreach ($app in $StandardApps) {
  if (Test-AppInstalled -App $app) {
    Write-LeftAligned "$FGDarkGreen$Char_BallotCheck Found: $($app.AppName)$Reset"
    $AlreadyPresentApps.Add($app.AppName)
  }
  else {
    Write-LeftAligned "$FGDarkRed$Char_FailureX Missing: $($app.AppName)$Reset"
    $AppsToInstall += $app
  }
}

Write-Host ""
if ($AppsToInstall.Count -gt 0) {
  $AppsToInstall = $AppsToInstall | Sort-Object InstallOrder
  Write-Boundary $FGDarkBlue
  Write-LeftAligned "$FGDarkYellow Missing applications: $($AppsToInstall.Count)$Reset"
  Write-Host ""
  
  Write-BodyTitle "INSTALLATION QUEUE"
  foreach ($app in $AppsToInstall) {
    Write-LeftAligned "$FGWhite $Char_Finger $($app.AppName)$Reset"
  }

  $res = Invoke-AnimatedPause "INSTALL"
  if ($res.VirtualKeyCode -ne 13) {
    Write-LeftAligned "$FGDarkYellow Installation canceled by user.$Reset"
    Stop-Transcript
    Write-Footer
    exit
  }

  Write-Boundary $FGDarkBlue
  Write-LeftAligned "$FGDarkYellow Starting installation...$Reset"
  
  foreach ($app in $AppListToInstall = $AppsToInstall) { Invoke-GenericInstall -App $app }
}
else {
  Write-LeftAligned "$FGGreen$Char_HeavyCheck All applications installed.$Reset"
}

# --- FINAL SUMMARY ---
Stop-Transcript | Out-Null
$logContent = [System.Collections.Generic.List[string]]::new()
$logContent.Add("========================================")
$logContent.Add(" App Installation Log")
$logContent.Add("========================================")
$logContent.Add("Date: $(Get-Date)")
$logContent.Add("User: $env:USERNAME")
$logContent.Add("")

$successes = @($Summary | Where-Object { $_.Present })
$failures = @($Summary | Where-Object { -not $_.Present })

$logContent.Add("--- Success ($($successes.Count)) ---")
if ($successes.Count -gt 0) { $successes | ForEach-Object { $logContent.Add("- $($_.AppName)") } } else { $logContent.Add("None") }
$logContent.Add("")

$logContent.Add("--- Failed ($($failures.Count)) ---")
if ($failures.Count -gt 0) { $failures | ForEach-Object { $logContent.Add("- $($_.AppName) (Exit: $($_.Exit))") } } else { $logContent.Add("None") }
$logContent.Add("")

$logContent | Out-File -FilePath $SummaryLogPath -Encoding UTF8 -Force

Write-Boundary $FGDarkBlue
Write-LeftAligned "Summary: $SummaryLogPath"
Write-LeftAligned "Transcript: $TranscriptLogPath"

Write-Host ""
Write-LeftAligned "Waiting 10s for services..."
Start-Sleep -Seconds 10

# --- VERIFICATION ---
Write-Host ""
Write-Boundary $FGDarkGray

$StillMissingApps = [System.Collections.Generic.List[string]]::new()
foreach ($app in $AppsToInstall) {
  if (-not (Test-AppInstalled -App $app)) {
    $isUserContextApp = (($app.ContainsKey('RegistryScope') -and $app.RegistryScope -eq 'User') -or
      (($app.ContainsKey('CheckMethod') -and $app.CheckMethod -eq 'Appx') -and ($app.ContainsKey('Source') -and $app.Source -eq 'msstore'))) -and
    ($app.WingetScope -ne 'Machine')
    if (-not $isUserContextApp) { $StillMissingApps.Add($app.AppName) }
  }
}

if ($StillMissingApps.Count -eq 0) {
  Write-LeftAligned "$FGGreen$Char_HeavyCheck All requested applications installed!$Reset"
}
else {
  Write-LeftAligned "$FGRed$Char_FailureX Failed to install:$Reset"
  $StillMissingApps | ForEach-Object { Write-LeftAligned "$FGRed - $_$Reset" -Indent 4 }
}
Write-Boundary $FGDarkGray

# --- [NEW] RE-ENABLE CONTROLLED FOLDER ACCESS ---
Write-Host ""
Write-LeftAligned "Attempting to re-enable 'Controlled Folder Access'..."

try {
  # Enable Controlled Folder Access
  Set-MpPreference -EnableControlledFolderAccess Enabled -ErrorAction Stop
    
  # Verify the setting
  $newPrefs = Get-MpPreference
  if ($newPrefs.EnableControlledFolderAccess -eq 1) {
    Write-LeftAligned "$FGGreen$Char_HeavyCheck Controlled Folder Access re-enabled.$Reset"
  }
  else {
    Write-LeftAligned "$FGRed$Char_FailureX Failed to re-enable Controlled Folder Access.$Reset"
    Write-LeftAligned "$FGDarkYellow State: $($newPrefs.EnableControlledFolderAccess)$Reset"
  }
}
catch {
  Write-LeftAligned "$FGRed$Char_Warn Error re-enabling Controlled Folder Access:$Reset"
  Write-LeftAligned "$FGRed   $($_.Exception.Message)$Reset"
}
Write-Boundary $FGDarkGray
# --- [END NEW] ---

Write-Footer

