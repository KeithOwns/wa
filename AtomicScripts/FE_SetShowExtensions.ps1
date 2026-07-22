<#
.SYNOPSIS
    Configures File Explorer to show or hide file extensions.
.DESCRIPTION
    Toggles the registry key HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\HideFileExt.
    By default, sets file extensions to visible (0). Use -Reverse to hide file extensions (1).
.PARAMETER Reverse
    If specified, hides file extensions in File Explorer.
.EXAMPLE
    .\FE_SetShowExtensions.ps1
.EXAMPLE
    .\FE_SetShowExtensions.ps1 -Reverse
#>
param([switch]$Reverse)

# UI Location: File Explorer > View > Show

if ($Reverse) {
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 1 -Type DWord -Force
} else {
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0 -Type DWord -Force
}
