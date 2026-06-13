param([switch]$Reverse)

if ($Reverse) {
    Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true } | Invoke-CimMethod -MethodName SetTCPIPNetBIOS -Arguments @{TcpipNetbiosOptions=0}
} else {
    Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true } | Invoke-CimMethod -MethodName SetTCPIPNetBIOS -Arguments @{TcpipNetbiosOptions=2}
}
