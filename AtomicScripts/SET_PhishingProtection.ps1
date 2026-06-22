param([switch]$Reverse)

# Drives the "Phishing protection" toggle on Windows Security's
# Reputation-based protection settings page, instead of writing
# Policies\Microsoft\Windows\WTDS\Components\ServiceEnabled, which would lock
# that page as "managed by your organization."
# A prior run of the old registry-based version may have already left that
# value behind, which locks the control regardless of what this script does —
# remove it first so the toggle is actually interactive.
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WTDS\Components" -Name "ServiceEnabled" -Force -ErrorAction SilentlyContinue

Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

try { Start-Process "windowsdefender://appbrowser" -ErrorAction Stop } catch {}
Start-Sleep -Seconds 2

$desktop = [System.Windows.Automation.AutomationElement]::RootElement
$cond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, "Windows Security")
$window = $null
$deadline = (Get-Date).AddSeconds(10)
do {
    $window = $desktop.FindFirst([System.Windows.Automation.TreeScope]::Children, $cond)
    if ($window) { break }
    Start-Sleep -Milliseconds 500
} while ((Get-Date) -lt $deadline)

if ($window) {
    try {
        $drillCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, "Reputation-based protection settings")
        $drillLink = $window.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $drillCondition)
        if ($drillLink) {
            $drillLink.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
            Start-Sleep -Seconds 1
        }
    } catch {}

    # Match on name AND verify the element actually supports TogglePattern —
    # a heading/label Text control can also match the name search.
    $toggle = $null
    $allElements = $window.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
    foreach ($el in $allElements) {
        if ($el.Current.Name -like "*Phishing protection*") {
            try {
                $el.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern) | Out-Null
                $toggle = $el
                break
            } catch { continue }
        }
    }

    if ($toggle) {
        $togglePattern = $toggle.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern)
        $current = $togglePattern.Current.ToggleState
        $targetState = if ($Reverse) { [System.Windows.Automation.ToggleState]::Off } else { [System.Windows.Automation.ToggleState]::On }
        if ($current -ne $targetState) { $togglePattern.Toggle() }
        if ($Reverse) { Remove-ItemProperty -Path "HKLM:\SOFTWARE\WinAuto" -Name "LastRun_PhishingProtection" -Force -ErrorAction SilentlyContinue }
        else {
            if (-not (Test-Path "HKLM:\SOFTWARE\WinAuto")) { New-Item -Path "HKLM:\SOFTWARE\WinAuto" -Force | Out-Null }
            Set-ItemProperty -Path "HKLM:\SOFTWARE\WinAuto" -Name "LastRun_PhishingProtection" -Value (Get-Date).ToString() -Force
        }
    }

    try {
        $windowPattern = $window.GetCurrentPattern([System.Windows.Automation.WindowPattern]::Pattern)
        if ($windowPattern) { $windowPattern.Close() }
    } catch {}
}
