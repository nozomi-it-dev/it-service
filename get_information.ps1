# Generates an asset inventory report and saves to IT-USB or Desktop

$Host.UI.RawUI.WindowTitle = "Asset Inventory Report"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Get current date/time
$now = Get-Date
$date_str = $now.ToString("yyyy/MM/dd")
$time_str = $now.ToString("HH:mm:ss.ff")
$filename_date = $now.ToString("yyyy-MM-dd")

# Automatically find "IT-USB" Flash Drive
$output_path = $null
$drives = Get-Volume | Where-Object { $_.DriveType -eq 'Removable' -and $_.FileSystemLabel -like "*IT-USB*" }

if ($drives) {
    $output_path = $drives[0].DriveLetter + ":\"
}
else {
    $output_path = [Environment]::GetFolderPath("Desktop") + "\"
    Write-Host "Warning: IT-USB drive not found. Saving to Desktop instead."
    Start-Sleep -Seconds 3
}

$filename = "$env:COMPUTERNAME" + "_" + $filename_date + ".txt"
$fullpath = Join-Path $output_path $filename

# Initialize report file
@"
========================================
        IT DEVICE INVENTORY DATA
   Date/Time: $date_str  $time_str
========================================

"@ | Out-File -FilePath $fullpath -Encoding UTF8

# Get system information
$csProduct = Get-CimInstance -ClassName Win32_ComputerSystemProduct
$chassis = Get-CimInstance -ClassName Win32_SystemEnclosure
$bios = Get-CimInstance -ClassName Win32_BIOS
$os = Get-CimInstance -ClassName Win32_OperatingSystem
$cpu = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1

# [1] Category
$isLaptop = $chassis.ChassisTypes | Where-Object { $_ -in @(8, 9, 10, 11, 12, 14, 18, 21) }
$category = if ($isLaptop) { "Laptop" } else { "Desktop" }
"[1] Category: $category" | Out-File -FilePath $fullpath -Append -Encoding UTF8
"" | Out-File -FilePath $fullpath -Append -Encoding UTF8

# [2] Brand
"[2] Brand: $($csProduct.Vendor)" | Out-File -FilePath $fullpath -Append -Encoding UTF8
"" | Out-File -FilePath $fullpath -Append -Encoding UTF8

# [3] Model
"[3] Model: $($csProduct.Name)" | Out-File -FilePath $fullpath -Append -Encoding UTF8
"" | Out-File -FilePath $fullpath -Append -Encoding UTF8

# [4] Serial Number
"[4] Serial Number: $($bios.SerialNumber)" | Out-File -FilePath $fullpath -Append -Encoding UTF8
"" | Out-File -FilePath $fullpath -Append -Encoding UTF8

# [5] MAC Address - Physical Adapters Only
$macAddresses = Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.Virtual -eq $false } | Select-Object -ExpandProperty MacAddress
if ($macAddresses) {
    if ($macAddresses -is [array]) {
        foreach ($mac in $macAddresses) {
            "[5] MAC Address: $mac" | Out-File -FilePath $fullpath -Append -Encoding UTF8
        }
    } else {
        "[5] MAC Address: $macAddresses" | Out-File -FilePath $fullpath -Append -Encoding UTF8
    }
} else {
    "[5] MAC Address: Not available" | Out-File -FilePath $fullpath -Append -Encoding UTF8
}
"" | Out-File -FilePath $fullpath -Append -Encoding UTF8

# [6] IP Address - Physical Adapters Only
$physicalAdapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.Virtual -eq $false }
$ipAddresses = @()
foreach ($adapter in $physicalAdapters) {
    $ips = Get-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.AddressState -eq "Preferred" }
    foreach ($ip in $ips) {
        $ipAddresses += $ip.IPAddress
    }
}
if ($ipAddresses) {
    foreach ($ip in $ipAddresses) {
        "[6] IP Address: $ip" | Out-File -FilePath $fullpath -Append -Encoding UTF8
    }
} else {
    "[6] IP Address: Not available" | Out-File -FilePath $fullpath -Append -Encoding UTF8
}
"" | Out-File -FilePath $fullpath -Append -Encoding UTF8

# [7] Device Name
"[7] Device Name: $env:COMPUTERNAME" | Out-File -FilePath $fullpath -Append -Encoding UTF8
"" | Out-File -FilePath $fullpath -Append -Encoding UTF8

# [8] Key Specs
"[8] Key Specs:" | Out-File -FilePath $fullpath -Append -Encoding UTF8

# OS Version - Simplified (Windows 10/11 + Home/Pro)
$osCaption = $os.Caption
$winVersion = if ($osCaption -like "*Windows 11*") { "Windows 11" } 
elseif ($osCaption -like "*Windows 10*") { "Windows 10" }
else { $osCaption }

$osEdition = if ($osCaption -like "*Pro*") { "Pro" }
elseif ($osCaption -like "*Home*") { "Home" }
elseif ($osCaption -like "*Enterprise*") { "Enterprise" }
elseif ($osCaption -like "*Education*") { "Education" }
else { "" }

$osDisplay = if ($osEdition) { "$winVersion $osEdition" } else { $winVersion }
"    OS: $osDisplay" | Out-File -FilePath $fullpath -Append -Encoding UTF8

# CPU
"    CPU: $($cpu.Name)" | Out-File -FilePath $fullpath -Append -Encoding UTF8

# RAM - Get detailed information with model names
$ramModules = Get-CimInstance -ClassName Win32_PhysicalMemory
$ramList = @()
foreach ($mem in $ramModules) {
    $name = $mem.PartNumber.Trim()
    if (-not $name) { $name = "Unknown RAM" }
    $size = [math]::Round($mem.Capacity / 1GB)
    $speed = $mem.Speed
    $ramList += "$name $size GB @ $speed MHz"
}
foreach ($ram in $ramList) {
    "    RAM: $ram" | Out-File -FilePath $fullpath -Append -Encoding UTF8
}

# Storage (Internal drives only, exclude USB) - Show model names
$disks = Get-CimInstance -ClassName Win32_DiskDrive | Where-Object { $_.InterfaceType -notlike "*USB*" }
foreach ($disk in $disks) {
    $model = $disk.Model.Trim()
    "    Storage: $model" | Out-File -FilePath $fullpath -Append -Encoding UTF8
}
"" | Out-File -FilePath $fullpath -Append -Encoding UTF8

# Additional Information Section
"========================================
         ADDITIONAL INFORMATION
========================================
" | Out-File -FilePath $fullpath -Append -Encoding UTF8

# Device ID
"Device ID: $($csProduct.UUID)" | Out-File -FilePath $fullpath -Append -Encoding UTF8

# Product ID
$productId = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name ProductId -ErrorAction SilentlyContinue).ProductId
"Product ID: $productId" | Out-File -FilePath $fullpath -Append -Encoding UTF8
"" | Out-File -FilePath $fullpath -Append -Encoding UTF8

Write-Host $fullpath