<#
.SYNOPSIS
    Configures File Explorer to show or hide hidden and system files.
.DESCRIPTION
    Modifies registry values 'Hidden' and 'ShowSuperHidden' under Explorer\Advanced.
    By default, shows hidden and operating system files. Use -Reverse to hide them.
.PARAMETER Reverse
    If specified, hides hidden files and system files in File Explorer.
.EXAMPLE
    .\FE_SetShowHidden.ps1
.EXAMPLE
    .\FE_SetShowHidden.ps1 -Reverse
#>
param([switch]$Reverse)

# UI Location: File Explorer > View > Show

if ($Reverse) {
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 2 -Type DWord -Force
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowSuperHidden" -Value 0 -Type DWord -Force
} else {
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowSuperHidden" -Value 1 -Type DWord -Force
}
