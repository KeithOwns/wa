<#
.SYNOPSIS
    Configures System & Privacy Configuration setting (ST_RunSystemCleanup).
.DESCRIPTION
    Applies security hardening or system configuration for ST_RunSystemCleanup in the Windows environment.
.EXAMPLE
    .\ST_RunSystemCleanup.ps1
#>
# UI Location: Settings > System > Storage > Temporary files
$paths = @("$env:TEMP", "$env:WINDIR\Temp")
foreach ($p in $paths) {
    if (Test-Path $p) {
        Get-ChildItem -Path $p -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
}

