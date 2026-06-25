# UI Location: Settings > System > Storage > Temporary files
$paths = @("$env:TEMP", "$env:WINDIR\Temp")
foreach ($p in $paths) {
    if (Test-Path $p) {
        Get-ChildItem -Path $p -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
}
