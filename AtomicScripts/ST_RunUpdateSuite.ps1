# UI Location: Settings > Windows Update (also opens Microsoft Store > Library / Downloads & updates)
Install-Module PSWindowsUpdate -Force -AcceptLicense; Get-WindowsUpdate -Install -AcceptAll
