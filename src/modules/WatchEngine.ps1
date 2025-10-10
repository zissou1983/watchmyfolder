class WatchEngine {
    [System.IO.FileSystemWatcher]$Watcher
    [System.Collections.Queue]$FileQueue
    [System.Timers.Timer]$ProcessTimer
    [Logger]$Logger
    [hashtable]$Config
    [hashtable]$FileStates
    [scriptblock]$FileReadyCallback
    [PerformanceMonitor]$PerformanceMonitor
    
    WatchEngine([Logger]$Logger, [hashtable]$Config) {
        $this.Logger = $Logger
        $this.Config = $Config
        $this.FileQueue = New-Object System.Collections.Queue
        $this.FileStates = @{}
        $this.PerformanceMonitor = New-Object PerformanceMonitor
        $this.InitializeTimer()
    }
    
    [void] InitializeTimer() {
        $this.ProcessTimer = New-Object System.Timers.Timer
        $this.ProcessTimer.Interval = $this.Config.Performance.ProcessingInterval * 1000
        $this.ProcessTimer.AutoReset = $true
        
        # Event-Handler für Timer
        $timerHandler = {
            $this.ProcessQueue()
        }.GetNewClosure()
        
        Register-ObjectEvent -InputObject $this.ProcessTimer -EventName Elapsed -Action $timerHandler | Out-Null
    }
    
    [void] Start([string]$WatchPath) {
        try {
            $this.Logger.Info("Starte Watch Engine für Pfad: $WatchPath", @{})
            
            if (-not (Test-Path $WatchPath)) {
                throw "Watch-Pfad existiert nicht: $WatchPath"
            }
            
            $this.Watcher = New-Object System.IO.FileSystemWatcher
            $this.Watcher.Path = $WatchPath
            $this.Watcher.IncludeSubdirectories = $true
            $this.Watcher.EnableRaisingEvents = $true
            
            # Event-Handler registrieren
            $createdHandler = {
                param($sender, $e)
                $this.OnFileCreated($e)
            }.GetNewClosure()
            
            Register-ObjectEvent -InputObject $this.Watcher -EventName Created -Action $createdHandler | Out-Null
            
            $changedHandler = {
                param($sender, $e)
                $this.OnFileChanged($e)
            }.GetNewClosure()
            
            Register-ObjectEvent -InputObject $this.Watcher -EventName Changed -Action $changedHandler | Out-Null
            
            $renamedHandler = {
                param($sender, $e)
                $this.OnFileRenamed($e)
            }.GetNewClosure()
            
            Register-ObjectEvent -InputObject $this.Watcher -EventName Renamed -Action $renamedHandler | Out-Null
            
            # Timer starten
            $this.ProcessTimer.Start()
            
            $this.Logger.Info("Watch Engine erfolgreich gestartet", @{})
            
        } catch {
            $this.Logger.Error("Fehler beim Starten der Watch Engine: $($_.Exception.Message)", @{})
            throw
        }
    }
    
    [void] Stop() {
        try {
            $this.Logger.Info("Stoppe Watch Engine", @{})
            
            if ($this.Watcher) {
                $this.Watcher.EnableRaisingEvents = $false
                $this.Watcher.Dispose()
            }
            
            if ($this.ProcessTimer) {
                $this.ProcessTimer.Stop()
                $this.ProcessTimer.Dispose()
            }
            
            # Verbleibende Queue verarbeiten
            $this.ProcessQueue()
            
            $this.Logger.Info("Watch Engine gestoppt", @{})
            
        } catch {
            $this.Logger.Error("Fehler beim Stoppen der Watch Engine: $($_.Exception.Message)", @{})
        }
    }
    
    [void] OnFileCreated([System.IO.FileSystemEventArgs]$EventArgs) {
        $this.AddToQueue($EventArgs.FullPath, "Created")
    }
    
    [void] OnFileChanged([System.IO.FileSystemEventArgs]$EventArgs) {
        $this.AddToQueue($EventArgs.FullPath, "Changed")
    }
    
    [void] OnFileRenamed([System.IO.RenamedEventArgs]$EventArgs) {
        $this.AddToQueue($EventArgs.FullPath, "Renamed")
    }
    
    [void] AddToQueue([string]$FilePath, [string]$EventType) {
        try {
            # Queue-Überlauf prüfen
            if ($this.FileQueue.Count -ge $this.Config.Performance.QueueMaxSize) {
                $this.Logger.Warning("Queue-Überlauf! Datei wird übersprungen", @{ 
                    "File" = $FilePath
                    "QueueSize" = $this.FileQueue.Count 
                })
                return
            }
            
            $queueItem = @{
                "FilePath" = $FilePath
                "EventType" = $EventType
                "Timestamp" = Get-Date
                "RetryCount" = 0
            }
            
            $this.FileQueue.Enqueue($queueItem)
            $this.Logger.Debug("Datei zur Queue hinzugefügt: $FilePath ($EventType)", @{})
            
        } catch {
            $this.Logger.Error("Fehler beim Hinzufügen zur Queue: $($_.Exception.Message)", @{ "File" = $FilePath })
        }
    }
    
    [void] ProcessQueue() {
        try {
            $processedCount = 0
            $maxProcessPerCycle = 10

            # Queue-Größe für Performance-Monitoring aktualisieren
            $this.PerformanceMonitor.UpdateQueueSize($this.FileQueue.Count)

            while ($this.FileQueue.Count -gt 0 -and $processedCount -lt $maxProcessPerCycle) {
                $queueItem = $this.FileQueue.Dequeue()

                if ($this.IsFileReady($queueItem)) {
                    $this.ProcessFile($queueItem)
                    $processedCount++
                } else {
                    # Zurück in die Queue wenn noch nicht bereit
                    if ($queueItem.RetryCount -lt 5) {
                        $queueItem.RetryCount++
                        $this.FileQueue.Enqueue($queueItem)
                    } else {
                        $this.Logger.Warning("Datei nach 5 Versuchen übersprungen", @{ "File" = $queueItem.FilePath })
                        $this.PerformanceMonitor.RecordError()
                    }
                }
            }

            if ($processedCount -gt 0) {
                $this.Logger.Debug("Queue verarbeitet: $processedCount Dateien, $($this.FileQueue.Count) verbleibend", @{})
            }

        } catch {
            $this.Logger.Error("Fehler bei Queue-Verarbeitung: $($_.Exception.Message)", @{})
            $this.PerformanceMonitor.RecordError()
        }
    }
    
    [bool] IsFileReady([hashtable]$QueueItem) {
        try {
            $filePath = $QueueItem.FilePath
            
            # Datei existiert noch?
            if (-not (Test-Path $filePath)) {
                return $false
            }
            
            $file = Get-Item $filePath
            
            # Karenzzeit prüfen
            $gracePeriod = $this.Config.WatchFolders[0].GracePeriod
            $timeSinceEvent = (Get-Date) - $QueueItem.Timestamp
            if ($timeSinceEvent.TotalSeconds -lt $gracePeriod) {
                return $false
            }
            
            # Datei-Lock prüfen
            if ($this.IsFileLocked($file)) {
                return $false
            }
            
            # Größenstabilität prüfen
            if ($this.HasFileSizeChanged($file)) {
                return $false
            }
            
            return $true
            
        } catch {
            $this.Logger.Warning("Fehler bei Datei-Bereitschaftsprüfung: $($_.Exception.Message)", @{ "File" = $QueueItem.FilePath })
            return $false
        }
    }
    
    [bool] IsFileLocked([System.IO.FileInfo]$File) {
        try {
            $stream = $File.Open([System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::None)
            $stream.Close()
            return $false
        } catch {
            return $true
        }
    }
    
    [bool] HasFileSizeChanged([System.IO.FileInfo]$File) {
        $filePath = $File.FullName
        $currentSize = $File.Length
        
        if ($this.FileStates.ContainsKey($filePath)) {
            $lastSize = $this.FileStates[$filePath].Size
            $lastCheck = $this.FileStates[$filePath].LastCheck
            
            # Wenn sich die Größe geändert hat
            if ($currentSize -ne $lastSize) {
                $this.FileStates[$filePath] = @{ "Size" = $currentSize; "LastCheck" = Get-Date }
                return $true
            }
            
            # Wenn die Größe gleich ist, aber weniger als 5 Sekunden vergangen sind
            if ((Get-Date) - $lastCheck -lt [TimeSpan]::FromSeconds(5)) {
                return $true
            }
        } else {
            # Erste Prüfung - Status speichern
            $this.FileStates[$filePath] = @{ "Size" = $currentSize; "LastCheck" = Get-Date }
            return $true
        }
        
        return $false
    }
    
    [void] ProcessFile([hashtable]$QueueItem) {
        try {
            $file = Get-Item $QueueItem.FilePath -ErrorAction Stop
            $this.Logger.Info("Verarbeite Datei: $($file.FullName)", @{})

            # Event für weitere Verarbeitung auslösen
            $this.OnFileReady($file)

            # Erfolgreich verarbeitete Datei tracken
            $this.PerformanceMonitor.RecordFileProcessed()

            # Cleanup des FileStates
            if ($this.FileStates.ContainsKey($QueueItem.FilePath)) {
                $this.FileStates.Remove($QueueItem.FilePath)
            }

        } catch {
            $this.Logger.Error("Fehler bei Dateiverarbeitung: $($_.Exception.Message)", @{ "File" = $QueueItem.FilePath })
            $this.PerformanceMonitor.RecordError()
        }
    }
    
    [hashtable] GetPerformanceMetrics() {
        return $this.PerformanceMonitor.GetMetrics()
    }

    [string] GetPerformanceMetricsJson() {
        return $this.PerformanceMonitor.GetMetricsJson()
    }
}