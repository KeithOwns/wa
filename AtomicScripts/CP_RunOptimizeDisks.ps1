<#
.SYNOPSIS
    Configures Control Panel / Disk Optimization setting (CP_RunOptimizeDisks).
.DESCRIPTION
    Applies security hardening or system configuration for CP_RunOptimizeDisks in the Windows environment.
.EXAMPLE
    .\CP_RunOptimizeDisks.ps1
#>
# UI Location: legacy Optimize Drives dialog (dfrgui.exe), reached via Settings > System > Storage > Disks & volumes
Optimize-Volume -DriveLetter C -ReTrim -Defrag -Verbose

