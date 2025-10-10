Describe "PerformanceMonitor Tests" {
    BeforeAll {
        . "$PSScriptRoot\..\..\src\modules\PerformanceMonitor.ps1"
    }

    Context "PerformanceMonitor Initialization" {
        It "Should create a PerformanceMonitor instance" {
            $monitor = [PerformanceMonitor]::new()
            $monitor | Should -Not -BeNullOrEmpty
            $monitor.Metrics | Should -Not -BeNullOrEmpty
        }

        It "Should initialize with zero values" {
            $monitor = [PerformanceMonitor]::new()
            $metrics = $monitor.GetMetrics()

            $metrics.FilesProcessed | Should -Be 0
            $metrics.ErrorsCount | Should -Be 0
            $metrics.QueueSize | Should -Be 0
        }
    }

    Context "File Processing Tracking" {
        It "Should track processed files" {
            $monitor = [PerformanceMonitor]::new()

            $monitor.RecordFileProcessed()
            $monitor.RecordFileProcessed()

            $metrics = $monitor.GetMetrics()
            $metrics.FilesProcessed | Should -Be 2
        }

        It "Should track errors" {
            $monitor = [PerformanceMonitor]::new()

            $monitor.RecordError()
            $monitor.RecordError()
            $monitor.RecordError()

            $metrics = $monitor.GetMetrics()
            $metrics.ErrorsCount | Should -Be 3
        }

        It "Should calculate error rate correctly" {
            $monitor = [PerformanceMonitor]::new()

            # 2 Dateien verarbeitet, 1 Fehler
            $monitor.RecordFileProcessed()
            $monitor.RecordFileProcessed()
            $monitor.RecordError()

            $metrics = $monitor.GetMetrics()
            $metrics.ErrorRatePercent | Should -Be 50
        }
    }

    Context "Queue Size Tracking" {
        It "Should update and return queue size" {
            $monitor = [PerformanceMonitor]::new()

            $monitor.UpdateQueueSize(5)
            $metrics = $monitor.GetMetrics()
            $metrics.QueueSize | Should -Be 5

            $monitor.UpdateQueueSize(10)
            $metrics = $monitor.GetMetrics()
            $metrics.QueueSize | Should -Be 10
        }
    }

    Context "Uptime Tracking" {
        It "Should track uptime" {
            $monitor = [PerformanceMonitor]::new()

            Start-Sleep -Milliseconds 100  # Kurze Pause für Test

            $metrics = $monitor.GetMetrics()
            $metrics.Uptime.TotalSeconds | Should -BeGreaterThan 0
            $metrics.Uptime.Formatted | Should -Not -BeNullOrEmpty
        }
    }

    Context "JSON Serialization" {
        It "Should return valid JSON" {
            $monitor = [PerformanceMonitor]::new()
            $monitor.RecordFileProcessed()
            $monitor.RecordError()

            $json = $monitor.GetMetricsJson()
            $json | Should -Not -BeNullOrEmpty

            # JSON sollte parsbar sein
            $parsed = $json | ConvertFrom-Json
            $parsed.FilesProcessed | Should -Be 1
            $parsed.ErrorsCount | Should -Be 1
        }
    }

    Context "Reset Functionality" {
        It "Should reset all counters" {
            $monitor = [PerformanceMonitor]::new()

            $monitor.RecordFileProcessed()
            $monitor.RecordFileProcessed()
            $monitor.RecordError()
            $monitor.UpdateQueueSize(5)

            $metricsBefore = $monitor.GetMetrics()
            $metricsBefore.FilesProcessed | Should -Be 2
            $metricsBefore.ErrorsCount | Should -Be 1
            $metricsBefore.QueueSize | Should -Be 5

            $monitor.Reset()

            $metricsAfter = $monitor.GetMetrics()
            $metricsAfter.FilesProcessed | Should -Be 0
            $metricsAfter.ErrorsCount | Should -Be 0
            # QueueSize wird nicht zurückgesetzt, da es ein Live-Wert ist
        }
    }
}