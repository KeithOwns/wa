param([switch]$Reverse)

# UI Location: Windows Security > Device security > Core isolation (Local Security Authority protection — only present on newer Windows 11 builds)

if ($Reverse) {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RunAsPPL" -Value 0 -Type DWord -Force
} else {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RunAsPPL" -Value 1 -Type DWord -Force
}
