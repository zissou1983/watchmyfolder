class WatchEngine {
    [System.IO.FileSystemWatcher]$Watcher
    [System.Collections.Queue]$FileQueue
    [System.Timers.Timer]$ProcessTimer
    [System.Timers.Timer]$PollingTimer        # SMB Fallback Polling
    [System.Timers.Timer]$WatcherHealthTimer  # Watcher Health Check
    [Logger]$Logger
    [hashtable]$Config
    [hashtable]$FileStates
    [hashtable]$KnownFiles                    # Für Polling-Modus
    [scriptblock]$FileReadyCallback
    [PerformanceMonitor]$PerformanceMonitor
    [bool]$IsNetworkPath                      # SMB/UNC Pfad Erkennung
    [string]$CurrentWatchPath
    [datetime]$LastWatcherEvent               # Für Health Check
    
    WatchEngine([Logger]$Logger, [hashtable]$Config) {
        $this.Logger = $Logger
        $this.Config = $Config
        $this.FileQueue = New-Object System.Collections.Queue
        $this.FileStates = @{}
        $this.KnownFiles = @{}
        $this.PerformanceMonitor = New-Object PerformanceMonitor
        $this.IsNetworkPath = $false
        $this.LastWatcherEvent = Get-Date
        $this.InitializeTimer()
    }
    
    # Erkennt ob Pfad ein Netzlaufwerk/UNC ist
    [bool] DetectNetworkPath([string]$Path) {
        # UNC Pfad (\\server\share)
        if ($Path -match '^\\\\') {
            return $true
        }
        
        # Mapped Drive prüfen
        try {
            $drive = Split-Path -Path $Path -Qualifier
            if ($drive) {
                $driveInfo = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='$drive'" -ErrorAction SilentlyContinue
                if ($driveInfo -and $driveInfo.DriveType -eq 4) {
                    return $true
                }
            }
        } catch {
            $this.Logger.Debug("Konnte Laufwerkstyp nicht ermitteln: $($_.Exception.Message)", @{})
        }
        
        return $false
    }
    
    [void] InitializeTimer() {
        $this.ProcessTimer = New-Object System.Timers.Timer
        $this.ProcessTimer.Interval = $this.Config.Performance.ProcessingInterval * 1000
        $this.ProcessTimer.AutoReset = $true
        
        # Event-Handler für Timer mit Closure
        $engine = $this
        $timerHandler = {
            $engine.ProcessQueue()
        }
        
        Register-ObjectEvent -InputObject $this.ProcessTimer -EventName Elapsed -Action $timerHandler -SourceIdentifier "ProcessTimer" | Out-Null
    }
    
    # Polling Timer für SMB Fallback
    [void] InitializePollingTimer([int]$IntervalSeconds) {
        $this.PollingTimer = New-Object System.Timers.Timer
        $this.PollingTimer.Interval = $IntervalSeconds * 1000
        $this.PollingTimer.AutoReset = $true
        
        $engine = $this
        $pollingHandler = {
            $engine.PollForChanges()
        }
        
        Register-ObjectEvent -InputObject $this.PollingTimer -EventName Elapsed -Action $pollingHandler -SourceIdentifier "PollingTimer" | Out-Null
        $this.Logger.Info("Polling-Timer initialisiert (Interval: ${IntervalSeconds}s) für Netzlaufwerk-Support", @{})
    }
    
    # Health Check Timer für FileSystemWatcher
    [void] InitializeWatcherHealthCheck() {
        $this.WatcherHealthTimer = New-Object System.Timers.Timer
        $this.WatcherHealthTimer.Interval = 60000  # Alle 60 Sekunden
        $this.WatcherHealthTimer.AutoReset = $true
        
        $engine = $this
        $healthHandler = {
            $engine.CheckWatcherHealth()
        }
        
        Register-ObjectEvent -InputObject $this.WatcherHealthTimer -EventName Elapsed -Action $healthHandler -SourceIdentifier "HealthCheckTimer" | Out-Null
    }
    
    [void] CheckWatcherHealth() {
        try {
            # Wenn länger als 5 Minuten kein Event und Netzwerkpfad
            $timeSinceLastEvent = (Get-Date) - $this.LastWatcherEvent
            if ($this.IsNetworkPath -and $timeSinceLastEvent.TotalMinutes -gt 5) {
                $this.Logger.Warning("FileSystemWatcher möglicherweise inaktiv - starte neu...", @{})
                $this.RestartWatcher()
            }
        } catch {
            $this.Logger.Error("Fehler bei Watcher Health Check: $($_.Exception.Message)", @{})
        }
    }
    
    [void] RestartWatcher() {
        try {
            if ($this.Watcher) {
                $this.Watcher.EnableRaisingEvents = $false
                $this.Watcher.Dispose()
            }
            $this.Start($this.CurrentWatchPath)
            $this.Logger.Info("FileSystemWatcher erfolgreich neugestartet", @{})
        } catch {
            $this.Logger.Error("Fehler beim Neustart des Watchers: $($_.Exception.Message)", @{})
        }
    }
    
    [void] Start([string]$WatchPath) {
        try {
            $this.Logger.Info("Starte Watch Engine für Pfad: $WatchPath", @{})
            $this.CurrentWatchPath = $WatchPath
            
            if (-not (Test-Path $WatchPath)) {
                throw "Watch-Pfad existiert nicht: $WatchPath"
            }
            
            # Netzwerkpfad erkennen
            $this.IsNetworkPath = $this.DetectNetworkPath($WatchPath)
            if ($this.IsNetworkPath) {
                $this.Logger.Warning("Netzlaufwerk erkannt! Aktiviere erweiterte SMB-Unterstützung für: $WatchPath", @{})
            }
            
            $this.Watcher = New-Object System.IO.FileSystemWatcher
            $this.Watcher.Path = $WatchPath
            $this.Watcher.IncludeSubdirectories = $true
            
            # SMB-optimierte Buffer-Größe
            if ($this.IsNetworkPath) {
                $this.Watcher.InternalBufferSize = 65536  # 64KB für Netzwerk
            }
            
            $this.Watcher.EnableRaisingEvents = $true
            
            # Event-Handler mit geschlossener Variable (Closure)
            # Das Wort $this wird außerhalb des ScriptBlocks erfasst
            $engine = $this
            
            $createdScript = {
                param($sender, $e)
                $engine.OnFileCreated($e)
            }
            
            $changedScript = {
                param($sender, $e)
                $engine.OnFileChanged($e)
            }
            
            $renamedScript = {
                param($sender, $e)
                $engine.OnFileRenamed($e)
            }
            
            # Register die Scripts mit dem Watcher
            $null = Register-ObjectEvent -InputObject $this.Watcher -EventName Created -Action $createdScript -SourceIdentifier "WatchEngine_Created_$([guid]::NewGuid())"
            $null = Register-ObjectEvent -InputObject $this.Watcher -EventName Changed -Action $changedScript -SourceIdentifier "WatchEngine_Changed_$([guid]::NewGuid())"
            $null = Register-ObjectEvent -InputObject $this.Watcher -EventName Renamed -Action $renamedScript -SourceIdentifier "WatchEngine_Renamed_$([guid]::NewGuid())"
            
            # HINWEIS: Timer werden NICHT mehr gestartet
            # Stattdessen wird die Hauptschleife in WatchFolderService.ps1 
            # die PollForChanges() und ProcessQueue() Methoden direkt aufrufen
            
            # Polling aktivieren für ALLE Pfade (lokal und Netzwerk)
            # Das ist ein Workaround für Probleme mit FileSystemWatcher Events
            $this.ScanExistingFiles($WatchPath)
            
            # Polling Timer initialisieren (wird aber von der Hauptschleife aufgerufen, nicht gestartet)
            $this.InitializePollingTimer(10)
            
            # Bei Netzwerkpfaden: Health Check initialisieren
            if ($this.IsNetworkPath) {
                # Health Check für Watcher
                $this.InitializeWatcherHealthCheck()
                
                $this.Logger.Info("SMB-Modus aktiviert: Polling + Health Check aktiv", @{})
            }
            
            $this.Logger.Info("Watch Engine erfolgreich gestartet", @{})
            
        } catch {
            $this.Logger.Error("Fehler beim Starten der Watch Engine: $($_.Exception.Message)", @{})
            throw
        }
    }
    
    # Scannt existierende Dateien für Polling-Vergleich
    [void] ScanExistingFiles([string]$Path) {
        try {
            $files = Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue
            foreach ($file in $files) {
                $this.KnownFiles[$file.FullName] = @{
                    LastWriteTime = $file.LastWriteTime
                    Length = $file.Length
                }
            }
            $this.Logger.Debug("Initiale Dateiliste erstellt: $($this.KnownFiles.Count) Dateien", @{})
        } catch {
            $this.Logger.Warning("Fehler beim Scannen existierender Dateien: $($_.Exception.Message)", @{})
        }
    }
    
    # Polling-Fallback für SMB
    [void] PollForChanges() {
        try {
            if (-not $this.CurrentWatchPath -or -not (Test-Path $this.CurrentWatchPath)) {
                return
            }
            
            $currentFiles = @{}
            $files = Get-ChildItem -Path $this.CurrentWatchPath -Recurse -File -ErrorAction SilentlyContinue
            
            foreach ($file in $files) {
                $currentFiles[$file.FullName] = @{
                    LastWriteTime = $file.LastWriteTime
                    Length = $file.Length
                }
                
                # Neue Datei?
                if (-not $this.KnownFiles.ContainsKey($file.FullName)) {
                    $this.Logger.Debug("Polling: Neue Datei entdeckt: $($file.FullName)", @{})
                    $this.AddToQueue($file.FullName, "Created_Polling")
                }
                # Geänderte Datei?
                elseif ($this.KnownFiles[$file.FullName].LastWriteTime -ne $file.LastWriteTime -or
                        $this.KnownFiles[$file.FullName].Length -ne $file.Length) {
                    $this.Logger.Debug("Polling: Dateiänderung entdeckt: $($file.FullName)", @{})
                    $this.AddToQueue($file.FullName, "Changed_Polling")
                }
            }
            
            # Bekannte Dateien aktualisieren
            $this.KnownFiles = $currentFiles
            
        } catch {
            $this.Logger.Warning("Fehler beim Polling: $($_.Exception.Message)", @{})
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
            
            if ($this.PollingTimer) {
                $this.PollingTimer.Stop()
                $this.PollingTimer.Dispose()
            }
            
            if ($this.WatcherHealthTimer) {
                $this.WatcherHealthTimer.Stop()
                $this.WatcherHealthTimer.Dispose()
            }
            
            # Verbleibende Queue verarbeiten
            $this.ProcessQueue()
            
            $this.Logger.Info("Watch Engine gestoppt", @{})
            
        } catch {
            $this.Logger.Error("Fehler beim Stoppen der Watch Engine: $($_.Exception.Message)", @{})
        }
    }
    
    [void] OnFileCreated([System.IO.FileSystemEventArgs]$EventArgs) {
        $this.LastWatcherEvent = Get-Date
        $this.AddToQueue($EventArgs.FullPath, "Created")
    }
    
    [void] OnFileChanged([System.IO.FileSystemEventArgs]$EventArgs) {
        $this.LastWatcherEvent = Get-Date
        $this.AddToQueue($EventArgs.FullPath, "Changed")
    }
    
    [void] OnFileRenamed([System.IO.RenamedEventArgs]$EventArgs) {
        $this.LastWatcherEvent = Get-Date
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
            $notReadyItems = @()  # Sammle nicht-bereite Items separat

            # Queue-Größe für Performance-Monitoring aktualisieren
            $this.PerformanceMonitor.UpdateQueueSize($this.FileQueue.Count)

            # Verarbeite nur die aktuellen Items, nicht die die wir gerade hinzufügen
            $itemsToProcess = $this.FileQueue.Count
            $itemsProcessed = 0

            while ($itemsProcessed -lt $itemsToProcess -and $processedCount -lt $maxProcessPerCycle) {
                $queueItem = $this.FileQueue.Dequeue()
                $itemsProcessed++

                if ($this.IsFileReady($queueItem)) {
                    $this.ProcessFile($queueItem)
                    $processedCount++
                } else {
                    # Sammle nicht-bereite Items für später
                    if ($queueItem.RetryCount -lt 10) {  # Erhöht auf 10 Versuche
                        $queueItem.RetryCount++
                        $notReadyItems += $queueItem
                    } else {
                        $this.Logger.Warning("Datei nach 10 Versuchen übersprungen", @{ "File" = $queueItem.FilePath })
                        $this.PerformanceMonitor.RecordError()
                    }
                }
            }

            # Füge nicht-bereite Items wieder zur Queue hinzu (für nächsten Zyklus)
            foreach ($item in $notReadyItems) {
                $this.FileQueue.Enqueue($item)
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
                $this.Logger.Debug("IsFileReady: Datei existiert nicht mehr: $filePath", @{})
                return $false
            }
            
            $file = Get-Item $filePath
            
            # Karenzzeit prüfen (Minimum-Wartezeit)
            $gracePeriod = $this.Config.WatchFolders[0].GracePeriod
            $timeSinceEvent = (Get-Date) - $QueueItem.Timestamp
            $this.Logger.Debug("IsFileReady: $filePath - TimeSinceEvent: $($timeSinceEvent.TotalSeconds)s, GracePeriod: $gracePeriod", @{})
            if ($timeSinceEvent.TotalSeconds -lt $gracePeriod) {
                return $false
            }
            
            # Datei-Lock prüfen
            if ($this.IsFileLocked($file)) {
                $this.Logger.Debug("IsFileReady: Datei ist gesperrt: $filePath", @{})
                return $false
            }
            
            # LastWriteTime Prüfung - Datei sollte seit mindestens 2 Sekunden nicht mehr geschrieben worden sein
            $timeSinceLastWrite = (Get-Date) - $file.LastWriteTime
            if ($timeSinceLastWrite.TotalSeconds -lt 2) {
                $this.Logger.Debug("IsFileReady: Datei wurde kürzlich geschrieben: $filePath (vor $($timeSinceLastWrite.TotalSeconds)s)", @{})
                return $false
            }
            
            $this.Logger.Debug("IsFileReady: Datei ist bereit: $filePath", @{})
            return $true
            
        } catch {
            $this.Logger.Warning("Fehler bei Datei-Bereitschaftsprüfung: $($_.Exception.Message)", @{ "File" = $QueueItem.FilePath })
            return $false
        }
    }
    
    # Einfache Lock-Prüfung ohne Task (Task.Run funktioniert nicht in PowerShell Klassen)
    [bool] IsFileLocked([System.IO.FileInfo]$File) {
        try {
            $stream = [System.IO.File]::Open($File.FullName, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::None)
            $stream.Close()
            $stream.Dispose()
            return $false  # Datei ist NICHT gesperrt
        } catch {
            $this.Logger.Debug("Datei ist gesperrt: $($File.FullName)", @{})
            return $true   # Datei ist gesperrt
        }
    }
    
    [bool] IsFileStillBeingWritten([System.IO.FileInfo]$File) {
        try {
            # Konfigurierbare Parameter verwenden
            $maxWriteTimeThreshold = 2
            $requireExclusiveAccess = $true
            
            # Bei Netzlaufwerken: Längere Schwelle und kein exklusiver Zugriff
            if ($this.IsNetworkPath) {
                $maxWriteTimeThreshold = 5  # Mehr Zeit für SMB
                $requireExclusiveAccess = $false  # Exklusiver Zugriff problematisch auf SMB
            }
            
            if ($this.Config.Performance.FileReadiness) {
                $maxWriteTimeThreshold = $this.Config.Performance.FileReadiness.MaxWriteTimeThreshold
                $requireExclusiveAccess = $this.Config.Performance.FileReadiness.RequireExclusiveAccess
            }
            
            # Prüfe ob LastWriteTime sehr recent ist
            $timeSinceLastWrite = (Get-Date) - $File.LastWriteTime
            if ($timeSinceLastWrite.TotalSeconds -lt $maxWriteTimeThreshold) {
                $this.Logger.Debug("Datei noch zu frisch geschrieben: $($File.FullName) (vor $($timeSinceLastWrite.TotalSeconds)s)", @{})
                return $true
            }
            
            # Zusätzlicher Check: Versuche exklusiven Zugriff (wenn konfiguriert und kein Netzlaufwerk)
            if ($requireExclusiveAccess -and -not $this.IsNetworkPath) {
                try {
                    $stream = $File.Open([System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
                    $stream.Close()
                    return $false  # Datei kann exklusiv geöffnet werden = fertig
                } catch {
                    $this.Logger.Debug("Datei noch exklusiv verwendet: $($File.FullName)", @{})
                    return $true   # Datei ist noch in Verwendung
                }
            }
            
            return $false
            
        } catch {
            $this.Logger.Debug("Fehler bei IsFileStillBeingWritten: $($_.Exception.Message)", @{ "File" = $File.FullName })
            return $true  # Im Zweifel als 'noch nicht fertig' behandeln
        }
    }
    
    [bool] HasFileSizeChanged([System.IO.FileInfo]$File) {
        $filePath = $File.FullName
        $currentSize = $File.Length
        $currentLastWrite = $File.LastWriteTime
        
        if ($this.FileStates.ContainsKey($filePath)) {
            $lastSize = $this.FileStates[$filePath].Size
            $lastCheck = $this.FileStates[$filePath].LastCheck
            $lastWriteTime = $this.FileStates[$filePath].LastWriteTime
            
            # Wenn sich die Größe geändert hat
            if ($currentSize -ne $lastSize) {
                $this.FileStates[$filePath] = @{ 
                    "Size" = $currentSize
                    "LastCheck" = Get-Date
                    "LastWriteTime" = $currentLastWrite
                }
                return $true
            }
            
            # Wenn sich LastWriteTime geändert hat (Datei wird noch geschrieben)
            if ($currentLastWrite -ne $lastWriteTime) {
                $this.FileStates[$filePath] = @{ 
                    "Size" = $currentSize
                    "LastCheck" = Get-Date
                    "LastWriteTime" = $currentLastWrite
                }
                return $true
            }
            
            # Konfigurierbare Mindest-Stabilität
            $minStabilitySeconds = 3
            if ($this.Config.Performance.FileReadiness) {
                $minStabilitySeconds = $this.Config.Performance.FileReadiness.MinimumStabilitySeconds
            }
            
            if ((Get-Date) - $lastCheck -lt [TimeSpan]::FromSeconds($minStabilitySeconds)) {
                return $true
            }
        } else {
            # Erste Prüfung - Status speichern
            $this.FileStates[$filePath] = @{ 
                "Size" = $currentSize
                "LastCheck" = Get-Date
                "LastWriteTime" = $currentLastWrite
            }
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
    
    [void] OnFileReady([System.IO.FileInfo]$File) {
        if ($this.FileReadyCallback) {
            & $this.FileReadyCallback $File
        }
    }
    
    [hashtable] GetPerformanceMetrics() {
        return $this.PerformanceMonitor.GetMetrics()
    }

    [string] GetPerformanceMetricsJson() {
        return $this.PerformanceMonitor.GetMetricsJson()
    }
}
