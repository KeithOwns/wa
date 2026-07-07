param([switch]$Undo)

if ($Undo) {
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Edge" -Name "SmartScreenPuaEnabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
} else {
    New-Item -Path "HKCU:\Software\Microsoft\Edge" -Force | Out-Null; Set-ItemProperty -Path "HKCU:\Software\Microsoft\Edge" -Name "SmartScreenPuaEnabled" -Value 1 -Type DWord -Force
}
