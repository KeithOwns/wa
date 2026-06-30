# Real-Time Protection via the Windows Security UI (UI Automation).
# Opens Windows Security and clicks "Turn on" / "Restart now".
# UI Location: Windows Security > Virus & threat protection > Manage settings
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
# A newly launched window opens INACTIVE when another app (e.g. the PowerShell
# console running this script) holds the foreground. While inactive, the page's
# content is never rendered into the UI Automation tree — only window chrome
# appears — so the button is never found. Forcing the window foreground fixes it.
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WinAutoFG {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr after, int x, int y, int cx, int cy, uint flags);
}
"@

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
    # Force the window foreground so its content renders, then give it a moment.
    try {
        $hwnd = [IntPtr]$window.Current.NativeWindowHandle
        if ($hwnd -ne [IntPtr]::Zero) {
            [WinAutoFG]::ShowWindow($hwnd, 9) | Out-Null          # SW_RESTORE
            [WinAutoFG]::SetWindowPos($hwnd, [IntPtr]::Zero, 0, 0, 0, 0, 0x0043) | Out-Null  # NOMOVE|NOSIZE|SHOWWINDOW
            [WinAutoFG]::SetForegroundWindow($hwnd) | Out-Null
        }
    } catch {}
    Start-Sleep -Seconds 2

    foreach ($t in @("Turn on", "Restart now")) {
        $bc = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, $t)
        $button = $window.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $bc)
        if ($button) {
            $button.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
            break
        }
    }
}
