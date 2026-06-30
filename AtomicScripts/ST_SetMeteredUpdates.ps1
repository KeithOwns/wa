param([switch]$Reverse)

# Drives the "Get updates over metered connections" toggle on Windows Update's
# Advanced options page, instead of writing Policies\Microsoft\Windows\
# WindowsUpdate\AllowAutoWindowsUpdateDownloadOverMeteredNetwork, which would
# lock that page as "managed by your organization."
# A prior run of the old registry-based version may have already left that
# value behind, which locks the control regardless of what this script does —
# remove it first so the toggle is actually interactive.
# UI Location: Settings > Windows Update > Advanced options (metered connection toggle)
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "AllowAutoWindowsUpdateDownloadOverMeteredNetwork" -Force -ErrorAction SilentlyContinue

Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
# A newly launched Settings window opens INACTIVE when another app (e.g. the
# PowerShell console running this script) holds the foreground. While inactive,
# the page's XAML content is never rendered into the UI Automation tree — only
# the window chrome appears, so the toggle is never found and this step would
# silently do nothing. Forcing the window to the foreground makes it render.
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WinAutoFG {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr after, int x, int y, int cx, int cy, uint flags);
}
"@

try { Start-Process "ms-settings:windowsupdate-options" -ErrorAction Stop } catch {}
Start-Sleep -Seconds 2

$desktop = [System.Windows.Automation.AutomationElement]::RootElement
$cond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, "Settings")
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

    # Match on name AND verify the element actually supports TogglePattern —
    # the heading text "Download updates over metered connections" also
    # matches the name search but is a plain Text control, not the switch.
    $toggle = $null
    $allElements = $window.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
    foreach ($el in $allElements) {
        if ($el.Current.Name -like "*metered connection*") {
            try {
                $el.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern) | Out-Null
                $toggle = $el
                break
            } catch { continue }
        }
    }

    if ($toggle) {
        if (-not $toggle.Current.IsEnabled) {
            Write-Host "Toggle found but reports IsEnabled=False — still locked (stale Policies value, or a different lock entirely)." -ForegroundColor Yellow
        }
        $togglePattern = $toggle.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern)
        $current = $togglePattern.Current.ToggleState
        # forward = allow metered downloads (On); -Reverse = block them (Off)
        $targetState = if ($Reverse) { [System.Windows.Automation.ToggleState]::Off } else { [System.Windows.Automation.ToggleState]::On }
        # Note: the state read-back after Toggle() lags ~1-2s, so we don't
        # re-read to "verify" here — that gives false negatives. One Toggle()
        # call reliably flips the control.
        if ($current -ne $targetState) { $togglePattern.Toggle() }
        if ($Reverse) { Remove-ItemProperty -Path "HKLM:\SOFTWARE\WinAuto" -Name "LastRun_MeteredUpdates" -Force -ErrorAction SilentlyContinue }
        else {
            if (-not (Test-Path "HKLM:\SOFTWARE\WinAuto")) { New-Item -Path "HKLM:\SOFTWARE\WinAuto" -Force | Out-Null }
            Set-ItemProperty -Path "HKLM:\SOFTWARE\WinAuto" -Name "LastRun_MeteredUpdates" -Value (Get-Date).ToString() -Force
        }
    } else {
        Write-Host "No metered-connection toggle found." -ForegroundColor Yellow
    }

    try {
        $windowPattern = $window.GetCurrentPattern([System.Windows.Automation.WindowPattern]::Pattern)
        if ($windowPattern) { $windowPattern.Close() }
    } catch {}
}
