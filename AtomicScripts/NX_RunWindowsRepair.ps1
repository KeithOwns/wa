<#
.SYNOPSIS
    Configures Next-Gen Windows Hardening setting (NX_RunWindowsRepair).
.DESCRIPTION
    Applies security hardening or system configuration for NX_RunWindowsRepair in the Windows environment.
.EXAMPLE
    .\NX_RunWindowsRepair.ps1
#>
# UI Location: none (console-only: sfc /scannow, DISM /Online /Cleanup-Image /RestoreHealth)
sfc /scannow; DISM /Online /Cleanup-Image /RestoreHealth

