<#
.SYNOPSIS
    Configures System & Privacy Configuration setting (ST_RunUpdateSuite).
.DESCRIPTION
    Applies security hardening or system configuration for ST_RunUpdateSuite in the Windows environment.
.EXAMPLE
    .\ST_RunUpdateSuite.ps1
#>
# UI Location: Settings > Windows Update (also opens Microsoft Store > Library / Downloads & updates)
Install-Module PSWindowsUpdate -Force -AcceptLicense; Get-WindowsUpdate -Install -AcceptAll

