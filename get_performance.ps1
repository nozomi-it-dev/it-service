# Displays system performance metrics (CPU, GPU, Memory, Disks, Network)

$Host.UI.RawUI.WindowTitle = "System Performance Monitor"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Get-CPUInfo {
    $cpu = Get-CimInstance -ClassName Win32_Processor
    $cpuLoad = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue
    
    Write-Host "`n================== CPU =================" -ForegroundColor Cyan
    Write-Host "Model: $($cpu.Name)"
    Write-Host "Base Speed: $($cpu.MaxClockSpeed) MHz"
    Write-Host "Current Speed: $([math]::Round($cpu.CurrentClockSpeed / 1000, 2)) GHz"
    Write-Host "Cores: $($cpu.NumberOfCores)"
    Write-Host "Logical Processors: $($cpu.NumberOfLogicalProcessors)"
    Write-Host "Virtualization: $(if ($cpu.VirtualizationFirmwareEnabled) {'Enabled'} else {'Disabled'})"
    Write-Host "L1 Cache: $([math]::Round($cpu.L1CacheSize / 1KB, 0)) KB" -NoNewline
    Write-Host " | L2 Cache: $([math]::Round($cpu.L2CacheSize / 1KB, 0)) KB" -NoNewline
    Write-Host " | L3 Cache: $([math]::Round($cpu.L3CacheSize / 1KB, 0)) KB"
    Write-Host "Utilization: $([math]::Round($cpuLoad, 1))%" -ForegroundColor Yellow
    
    # Count processes, threads, and handles safely
    $processes = Get-Process
    $processCount = $processes.Count
    $threadCount = ($processes | ForEach-Object { $_.Threads.Count } | Measure-Object -Sum).Sum
    $handleCount = ($processes | Measure-Object -Property HandleCount -Sum).Sum
    
    Write-Host "Processes: $processCount" -NoNewline
    Write-Host " | Threads: $threadCount" -NoNewline
    Write-Host " | Handles: $handleCount"
    
    $uptime = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
    $uptimeSpan = (Get-Date) - $uptime
    Write-Host "Up time: $($uptimeSpan.Days)d $($uptimeSpan.Hours)h $($uptimeSpan.Minutes)m $($uptimeSpan.Seconds)s"
}

function Get-GPUInfo {
    Write-Host "`n================== GPU =================" -ForegroundColor Cyan
    
    $gpus = Get-CimInstance -ClassName Win32_VideoController
    
    foreach ($gpu in $gpus) {
        Write-Host "`n$($gpu.Name)"
        $vram = [math]::Round($gpu.AdapterRAM / 1GB, 1)
        if ($vram -gt 0) {
            Write-Host "VRAM: $vram GB"
        }
        Write-Host "Driver Version: $($gpu.DriverVersion)"
        Write-Host "Resolution: $($gpu.CurrentHorizontalResolution) x $($gpu.CurrentVerticalResolution)"
        Write-Host "Refresh Rate: $($gpu.CurrentRefreshRate) Hz"
    }
    
    # Try to get GPU usage (requires Windows 10/11)
    try {
        $gpuLoad = (Get-Counter '\GPU Engine(*)\Utilization Percentage' -ErrorAction SilentlyContinue).CounterSamples | 
        Measure-Object -Property CookedValue -Sum
        if ($gpuLoad.Sum -gt 0) {
            Write-Host "Utilization: $([math]::Round($gpuLoad.Sum, 1))%" -ForegroundColor Yellow
        }
    }
    catch {
        # GPU counters not available on this system
    }
}

function Get-MemoryInfo {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $totalMemory = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
    $freeMemory = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
    $usedMemory = $totalMemory - $freeMemory
    $memoryUsage = [math]::Round(($usedMemory / $totalMemory) * 100, 0)
    
    Write-Host "`n================ Memory ================" -ForegroundColor Cyan
    Write-Host "Total: $totalMemory GB"
    Write-Host "Used: $usedMemory GB ($memoryUsage%)" -ForegroundColor Yellow
    Write-Host "Available: $freeMemory GB"
    
    # Paged/Non-paged pool
    $pagedPool = [math]::Round($os.SizeStoredInPagingFiles / 1MB, 2)
    Write-Host "Committed: $([math]::Round(($os.TotalVirtualMemorySize - $os.FreeVirtualMemory) / 1MB, 1)) GB"
    Write-Host "Cached: $([math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory - (Get-Process | Measure-Object -Property WorkingSet -Sum).Sum / 1MB) / 1KB, 1)) GB"
}

function Get-DiskInfo {
    $disks = Get-CimInstance -ClassName Win32_DiskDrive
    
    Write-Host "`n================= Disks ================" -ForegroundColor Cyan
    
    foreach ($disk in $disks) {
        $diskName = $disk.Caption
        $diskSize = [math]::Round($disk.Size / 1GB, 0)
        $diskType = $disk.MediaType
        $interfaceType = $disk.InterfaceType
        
        # Skip USB drives in main listing
        if ($interfaceType -notlike "*USB*") {
            Write-Host "`nDisk: $diskName"
            Write-Host "Type: $interfaceType"
            Write-Host "Capacity: $diskSize GB"
            
            # Get partition info
            $partitions = Get-CimInstance -Query "ASSOCIATORS OF {Win32_DiskDrive.DeviceID='$($disk.DeviceID)'} WHERE AssocClass=Win32_DiskDriveToDiskPartition"
            foreach ($partition in $partitions) {
                $logicalDisks = Get-CimInstance -Query "ASSOCIATORS OF {Win32_DiskPartition.DeviceID='$($partition.DeviceID)'} WHERE AssocClass=Win32_LogicalDiskToPartition"
                foreach ($logical in $logicalDisks) {
                    $usedSpace = [math]::Round(($logical.Size - $logical.FreeSpace) / 1GB, 1)
                    $freeSpace = [math]::Round($logical.FreeSpace / 1GB, 1)
                    $totalSpace = [math]::Round($logical.Size / 1GB, 1)
                    $usage = [math]::Round((($logical.Size - $logical.FreeSpace) / $logical.Size) * 100, 0)
                    
                    Write-Host "  [$($logical.DeviceID)] Used: $usedSpace GB / $totalSpace GB ($usage%)" -ForegroundColor Yellow
                }
            }
            
            # Disk activity
            try {
                $diskPerf = Get-Counter "\PhysicalDisk($($disk.DeviceID.Replace('\','_')))\% Disk Time" -ErrorAction SilentlyContinue
                if ($diskPerf) {
                    Write-Host "  Active time: $([math]::Round($diskPerf.CounterSamples.CookedValue, 0))%"
                }
            }
            catch {
                # Skip if counter not available
            }
        }
    }
    
    # Show removable drives separately
    $removable = Get-Volume | Where-Object { $_.DriveType -eq 'Removable' -and $_.DriveLetter }
    if ($removable) {
        Write-Host "`n--- Removable Drives ---" -ForegroundColor Gray
        foreach ($drive in $removable) {
            $usedGB = [math]::Round(($drive.Size - $drive.SizeRemaining) / 1GB, 1)
            $totalGB = [math]::Round($drive.Size / 1GB, 1)
            $usage = if ($drive.Size -gt 0) { [math]::Round((($drive.Size - $drive.SizeRemaining) / $drive.Size) * 100, 0) } else { 0 }
            Write-Host "  [$($drive.DriveLetter):] $($drive.FileSystemLabel) - $usedGB GB / $totalGB GB ($usage%)"
        }
    }
}

function Get-NetworkInfo {
    Write-Host "`n================ Network ===============" -ForegroundColor Cyan
    
    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
    
    foreach ($adapter in $adapters) {
        Write-Host "`n$($adapter.Name) - $($adapter.InterfaceDescription)"
        Write-Host "Status: $($adapter.Status)" -ForegroundColor Green
        Write-Host "Link Speed: $($adapter.LinkSpeed)"
        
        # Get IP address
        $ipConfig = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
        if ($ipConfig) {
            Write-Host "IPv4: $($ipConfig.IPAddress)"
        }
        
        # Network throughput
        try {
            $sent = Get-Counter "\Network Interface($($adapter.InterfaceDescription))\Bytes Sent/sec" -ErrorAction SilentlyContinue
            $received = Get-Counter "\Network Interface($($adapter.InterfaceDescription))\Bytes Received/sec" -ErrorAction SilentlyContinue
            
            if ($sent -and $received) {
                $sentKbps = [math]::Round($sent.CounterSamples.CookedValue * 8 / 1KB, 0)
                $receivedKbps = [math]::Round($received.CounterSamples.CookedValue * 8 / 1KB, 0)
                Write-Host "Send: $sentKbps Kbps | Receive: $receivedKbps Kbps" -ForegroundColor Yellow
            }
        }
        catch {
            # Skip if counter not available
        }
    }
}

# Main execution
Clear-Host
Write-Host "========================================" -ForegroundColor Green
Write-Host "       SYSTEM PERFORMANCE MONITOR       " -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

Get-CPUInfo
Get-GPUInfo
Get-MemoryInfo
Get-DiskInfo
Get-NetworkInfo

Write-Host ""