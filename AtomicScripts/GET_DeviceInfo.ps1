$computerSystem = Get-CimInstance Win32_ComputerSystem
$processor = Get-CimInstance Win32_Processor
$os = Get-CimInstance Win32_OperatingSystem

$ramGB = [math]::Round($computerSystem.TotalPhysicalMemory / 1GB, 2)

$deviceInfo = [ordered]@{
    "Device name"   = $env:COMPUTERNAME
    "Processor"     = $processor.Name -join ", "
    "Installed RAM" = "$ramGB GB"
    "Device ID"     = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\SQMClient" -Name "MachineId" -ErrorAction SilentlyContinue).MachineId
    "Product ID"    = $os.SerialNumber
    "System type"   = $computerSystem.SystemType
    "OS Version"    = "$($os.Caption) $($os.Version)"
}

$deviceInfo | Format-List
