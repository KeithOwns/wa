param([switch]$Reverse)

# UI Location: Microsoft Edge > Settings > Privacy, search, and services > Security

$edgeKeyPath = "HKCU:\Software\Microsoft\Edge\SmartScreenPuaEnabled"
$targetEdge = if ($Reverse) { 0 } else { 1 }

if (-not (Test-Path $edgeKeyPath)) { New-Item -Path $edgeKeyPath -Force | Out-Null }
Set-ItemProperty -Path $edgeKeyPath -Name "(default)" -Value $targetEdge -Type DWord -Force
