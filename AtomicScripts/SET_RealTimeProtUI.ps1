# Real-Time Protection via the Windows Security UI (UI Automation).
# Opens Windows Security and clicks "Turn on" / "Restart now".
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

try { Start-Process "windowsdefender://threat" -ErrorAction Stop }
catch { Start-Process "explorer.exe" -ArgumentList "windowsdefender://threat" }
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
    foreach ($t in @("Turn on", "Restart now")) {
        $bc = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, $t)
        $button = $window.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $bc)
        if ($button) {
            $button.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
            break
        }
    }
}
