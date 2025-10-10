class PerformanceMonitor {
    [hashtable]$Metrics
    [System.Diagnostics.PerformanceCounter]$CpuCounter
    [System.Diagnostics.PerformanceCounter]$MemoryCounter
    [System.Collections.Generic.Queue[DateTime]]$ProcessingTimes
    [int]$FilesProcessed
    [int]$ErrorsCount
    [DateTime]$StartTime

    PerformanceMonitor() {
        $this.Metrics = @{}
        $this.ProcessingTimes = New-Object System.Collections.Generic.Queue[DateTime]
        $this.FilesProcessed = 0
        $this.ErrorsCount = 0
        $this.StartTime = Get-Date

        # Performance Counter für CPU und Memory
        try {
            $this.CpuCounter = New-Object System.Diagnostics.PerformanceCounter("Processor", "% Processor Time", "_Total")
            $this.MemoryCounter = New-Object System.Diagnostics.PerformanceCounter("Memory", "Available MBytes")
        } catch {
            Write-Warning "Performance Counter konnten nicht initialisiert werden: $($_.Exception.Message)"
        }
    }

    [void] RecordFileProcessed() {
        $this.FilesProcessed++
        $this.ProcessingTimes.Enqueue((Get-Date))

        # Behalte nur die letzten 1000 Einträge für Performance-Berechnungen
        while ($this.ProcessingTimes.Count -gt 1000) {
            $this.ProcessingTimes.Dequeue() | Out-Null
        }
    }

    [void] RecordError() {
        $this.ErrorsCount++
    }

    [void] UpdateQueueSize([int]$queueSize) {
        $this.Metrics["QueueSize"] = $queueSize
        $this.Metrics["LastQueueUpdate"] = Get-Date
    }

    [hashtable] GetMetrics() {
        $currentTime = Get-Date
        $uptime = $currentTime - $this.StartTime

        # Berechne Verarbeitungsgeschwindigkeit (Dateien pro Minute)
        $processingRate = 0
        if ($this.ProcessingTimes.Count -gt 1) {
            $timeSpan = $this.ProcessingTimes.Peek() - $this.ProcessingTimes.ToArray()[-1]
            if ($timeSpan.TotalMinutes -gt 0) {
                $processingRate = $this.ProcessingTimes.Count / $timeSpan.TotalMinutes
            }
        }

        # CPU und Memory Usage
        $cpuUsage = 0
        $memoryAvailable = 0
        try {
            if ($this.CpuCounter) {
                $cpuUsage = [math]::Round($this.CpuCounter.NextValue(), 2)
            }
            if ($this.MemoryCounter) {
                $memoryAvailable = [math]::Round($this.MemoryCounter.NextValue(), 2)
            }
        } catch {
            # Performance Counter Fehler ignorieren
        }

        # Fehler-Rate berechnen
        $errorRate = 0
        if ($this.FilesProcessed -gt 0) {
            $errorRate = [math]::Round(($this.ErrorsCount / $this.FilesProcessed) * 100, 2)
        }

        $queueSize = if ($this.Metrics.PSObject.Properties.Name -contains "QueueSize") { $this.Metrics.QueueSize } else { 0 }

        return @{
            "Uptime" = @{
                "TotalSeconds" = [math]::Round($uptime.TotalSeconds, 0)
                "Formatted" = "$([math]::Floor($uptime.TotalHours)):$(($uptime.Minutes).ToString('00')):$($uptime.Seconds.ToString('00'))"
            }
            "FilesProcessed" = $this.FilesProcessed
            "ErrorsCount" = $this.ErrorsCount
            "ErrorRatePercent" = $errorRate
            "ProcessingRatePerMinute" = [math]::Round($processingRate, 2)
            "QueueSize" = $queueSize
            "CpuUsagePercent" = $cpuUsage
            "MemoryAvailableMB" = $memoryAvailable
            "LastUpdate" = $currentTime.ToString("yyyy-MM-ddTHH:mm:ss")
        }
    }

    [string] GetMetricsJson() {
        $performanceMetrics = $this.GetMetrics()
        return $performanceMetrics | ConvertTo-Json -Depth 3
    }

    [void] Reset() {
        $this.FilesProcessed = 0
        $this.ErrorsCount = 0
        $this.ProcessingTimes.Clear()
        $this.StartTime = Get-Date
    }
}