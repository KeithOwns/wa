<#
.SYNOPSIS
    Configures Windows Security & Defender setting (WS_SetPhishing).
.DESCRIPTION
    Applies security hardening or system configuration for WS_SetPhishing in the Windows environment.
.PARAMETER Reverse
    If specified, reverses or restores default system behavior.
.EXAMPLE
    .\WS_SetPhishing.ps1
#>
param([switch]$Reverse)

# Drives the "Phishing protection" toggle on Windows Security's
# Reputation-based protection settings page, instead of writing
# Policies\Microsoft\Windows\WTDS\Components\ServiceEnabled, which would lock
# that page as "managed by your organization."
# A prior run of the old registry-based version may have already left that
# value behind, which locks the control regardless of what this script does —
# remove it first so the toggle is actually interactive.
# UI Location: Windows Security > App & browser control > Reputation-based protection settings
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WTDS\Components" -Name "ServiceEnabled" -Force -ErrorAction SilentlyContinue

Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
# A newly launched window opens INACTIVE when another app (e.g. the PowerShell
# console running this script) holds the foreground. While inactive, the page's
# XAML content is never rendered into the UI Automation tree — only the window
# chrome appears, so the toggle is never found and this step would silently do
# nothing. Forcing the window to the foreground makes it render.
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WinAutoFG {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr after, int x, int y, int cx, int cy, uint flags);
}
"@

# Windows Security keeps its own running process (SecHealthUI) and re-using an
# already-open window can show a stale "managed by your administrator" lock
# left over from before the registry value above was removed. Force a fresh
# instance so the page re-reads current policy state instead of cached state.
Stop-Process -Name "SecHealthUI" -Force -ErrorAction SilentlyContinue

# SecurityHealthService (the background service feeding that UI) can also
# cache the policy-managed flag independently of both the registry value and
# the UI process. Restarting it requires elevation this script already has.
Restart-Service -Name "SecurityHealthService" -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1

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

