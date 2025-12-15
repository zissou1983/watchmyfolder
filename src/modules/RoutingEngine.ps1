class RoutingEngine {
    [Logger]$Logger
    [hashtable]$Config
    [FormatClassifier]$Classifier
    [OperationTracker]$OperationTracker
    [object]$StatusAPI
    
    RoutingEngine([Logger]$Logger, [hashtable]$Config, [FormatClassifier]$Classifier) {
        $this.Logger = $Logger
        $this.Config = $Config
        $this.Classifier = $Classifier
        $this.OperationTracker = $null  # Wird später gesetzt
        $this.StatusAPI = $null  # Wird später gesetzt
    }
    
    [void] SetOperationTracker([OperationTracker]$OperationTracker) {
        $this.OperationTracker = $OperationTracker
        $this.Logger.Info("OperationTracker wurde gesetzt", @{})
    }

    [void] SetStatusAPI([object]$StatusAPI) {
        $this.StatusAPI = $StatusAPI
        $this.Logger.Info("StatusAPI wurde gesetzt", @{})
    }
    
    [bool] IsOperationCancelled([string]$FilePath) {
        if ($this.OperationTracker) {
            $activeOps = $this.OperationTracker.GetActiveOperations()
            $operation = $activeOps | Where-Object { $_.FilePath -eq $FilePath } | Select-Object -First 1
            return $operation -and $operation.Cancelled
        }
        return $false
    }
    
    [void] RouteFile([System.IO.FileInfo]$File) {
        try {
            $this.Logger.Info("Route Datei: $($File.FullName)", @{})
            
            # Operation aktualisieren (Status: analyzing -> processing)
            if ($this.OperationTracker) {
                # Finde Operation für diese Datei
                $activeOps = $this.OperationTracker.GetActiveOperations()
                $operation = $activeOps | Where-Object { $_.FilePath -eq $File.FullName } | Select-Object -First 1
                if ($operation) {
                    $this.OperationTracker.UpdateOperation($operation.Id, "processing", 25)
                }
            }

            # ZUERST CustomTabs prüfen - diese haben Priorität
            if ($this.TryRouteCustomTab($File)) {
                $this.Logger.Info("Datei via CustomTab geroutet", @{})
                return
            }
            
            # Datei klassifizieren
            $category = $this.Classifier.ClassifyFile($File)
            
            switch ($category) {
                "MAM" {
                    $this.RouteToMAM($File)
                }
                "BOX" {
                    $this.RouteToBOX($File)
                }
                "SYSTEM" {
                    $this.Logger.Debug("System-Datei ignoriert: $($File.FullName)", @{})
                    if ($this.OperationTracker) {
                        $activeOps = $this.OperationTracker.GetActiveOperations()
                        $operation = $activeOps | Where-Object { $_.FilePath -eq $File.FullName } | Select-Object -First 1
                        if ($operation) {
                            $this.OperationTracker.CompleteOperation($operation.Id, "ignored_system_file")
                        }
                    }
                    return
                }
                "UNKNOWN" {
                    $this.RouteToNight($File)
                }
                default {
                    $this.Logger.Warning("Unbekannte Kategorie: $category", @{ "File" = $File.FullName })
                    $this.RouteToNight($File)
                }
            }
            
        } catch {
            $this.Logger.Error("Fehler beim Routing: $($_.Exception.Message)", @{ "File" = $File.FullName })
            if ($this.OperationTracker) {
                $activeOps = $this.OperationTracker.GetActiveOperations()
                $operation = $activeOps | Where-Object { $_.FilePath -eq $File.FullName } | Select-Object -First 1
                if ($operation) {
                    $this.OperationTracker.UpdateOperation($operation.Id, "error", -1, $_.Exception.Message)
                }
            }
        }
    }
    
    [void] RouteToMAM([System.IO.FileInfo]$File) {
        try {
            if (-not $this.Config.Destinations.MAM.Enabled) {
                $this.Logger.Info("MAM-Routing deaktiviert, verschiebe zu Night")
                $this.RouteToNight($File)
                return
            }

            # Prüfe globale Nachtverarbeitung für Standard Watch Folder
            if (-not $this.IsInNightBatchWindowGlobal()) {
                $this.Logger.Debug("Nicht im globalen Nachtverarbeitungsfenster, verschiebe zu Night")
                $this.RouteToNight($File)
                return
            }

            $destination = $this.BuildMAMPath($File)
            $this.TransferFile($File, $destination, "MAM")

        } catch {
            $this.Logger.Error("Fehler beim MAM-Routing: $($_.Exception.Message)", @{ "File" = $File.FullName })
            $this.RouteToQuarantine($File, "MAM-Routing failed: $($_.Exception.Message)")
        }
    }
    
    [void] RouteToBOX([System.IO.FileInfo]$File) {
        try {
            if (-not $this.Config.Destinations.BOX.Enabled) {
                $this.Logger.Info("BOX-Routing deaktiviert, verschiebe zu Night")
                $this.RouteToNight($File)
                return
            }

            # Prüfe globale Nachtverarbeitung für Standard Watch Folder
            if (-not $this.IsInNightBatchWindowGlobal()) {
                $this.Logger.Debug("Nicht im globalen Nachtverarbeitungsfenster, verschiebe zu Night")
                $this.RouteToNight($File)
                return
            }

            $destination = $this.BuildBOXPath($File)
            $this.TransferFile($File, $destination, "BOX")

        } catch {
            $this.Logger.Error("Fehler beim BOX-Routing: $($_.Exception.Message)", @{ "File" = $File.FullName })
            $this.RouteToQuarantine($File, "BOX-Routing failed: $($_.Exception.Message)")
        }
    }
    
    [void] RouteToNight([System.IO.FileInfo]$File) {
        try {
            $destination = $this.BuildNightPath($File)
            $this.TransferFile($File, $destination, "Night")
            
            $this.Logger.Info("Datei zu Night-Ordner verschoben", @{
                "File" = $File.FullName
                "NightPath" = $destination
            })
            
        } catch {
            $this.Logger.Error("Fehler beim Verschieben zu Night: $($_.Exception.Message)", @{ "File" = $File.FullName })
            $this.RouteToQuarantine($File, "Night routing failed: $($_.Exception.Message)")
        }
    }
    
    [void] RouteToQuarantine([System.IO.FileInfo]$File, [string]$Reason) {
        try {
            $destination = $this.BuildQuarantinePath($File, $Reason)
            
            # DIREKTE Move-Operation ohne Retry-Logik um Endlosschleife zu vermeiden
            $targetDir = Split-Path $destination -Parent
            if (-not (Test-Path $targetDir)) {
                New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
            }
            
            # Einfaches Move ohne Checksum (Quarantine braucht keine Validierung)
            Move-Item -Path $File.FullName -Destination $destination -Force

            $this.Logger.Warning("Datei in Quarantäne verschoben", @{
                "File" = $File.FullName
                "Reason" = $Reason
                "QuarantinePath" = $destination
            })
            
            # Operation abschließen
            if ($this.OperationTracker) {
                $activeOps = $this.OperationTracker.GetActiveOperations()
                $operation = $activeOps | Where-Object { $_.FilePath -eq $File.FullName } | Select-Object -First 1
                if ($operation) {
                    $this.OperationTracker.CompleteOperation($operation.Id, "quarantined")
                }
            }

        } catch {
            $this.Logger.Error("Fehler beim Verschieben in Quarantäne: $($_.Exception.Message)", @{
                "File" = $File.FullName
                "Reason" = $Reason
            })
        }
    }
    
    [string] BuildMAMPath([System.IO.FileInfo]$File) {
        $basePath = $this.Config.Destinations.MAM.Path
        
        if ($this.Config.Destinations.MAM.PreserveFolderStructure) {
            # Relative Pfadstruktur beibehalten
            $watchFolder = $this.Config.WatchFolders[0].Path
            $relativePath = $File.DirectoryName.Replace($watchFolder, "").TrimStart("\")
            
            if ($relativePath) {
                $targetDir = Join-Path $basePath $relativePath
            } else {
                $targetDir = $basePath
            }
        } else {
            $targetDir = $basePath
        }
        
        return Join-Path $targetDir $File.Name
    }
    
    [string] BuildBOXPath([System.IO.FileInfo]$File) {
        $basePath = $this.Config.Destinations.BOX.Path
        $fileName = $File.Name
        
        if ($this.Config.Destinations.BOX.SanitizeFilenames) {
            $fileName = $this.SanitizePathForBOX($fileName)
        }
        
        if ($this.Config.Destinations.BOX.PreserveFolderStructure) {
            $watchFolder = $this.Config.WatchFolders[0].Path
            $relativePath = $File.DirectoryName.Replace($watchFolder, "").TrimStart("\")
            
            if ($relativePath) {
                $relativePath = $this.SanitizePathForBOX($relativePath)
                $targetDir = Join-Path $basePath $relativePath
            } else {
                $targetDir = $basePath
            }
        } else {
            $targetDir = $basePath
        }
        
        return Join-Path $targetDir $fileName
    }
    
    [string] BuildNightPath([System.IO.FileInfo]$File) {
        $basePath = $this.Config.Destinations.Night.Path
        
        # Datum-basierte Ordnerstruktur für Night
        $dateFolder = Get-Date -Format "yyyy-MM-dd"
        $targetDir = Join-Path $basePath $dateFolder
        
        # Original-Pfadstruktur beibehalten
        $watchFolder = $this.Config.WatchFolders[0].Path
        $relativePath = $File.DirectoryName.Replace($watchFolder, "").TrimStart("\")
        
        if ($relativePath) {
            $targetDir = Join-Path $targetDir $relativePath
        }
        
        return Join-Path $targetDir $File.Name
    }
    
    [string] BuildQuarantinePath([System.IO.FileInfo]$File, [string]$Reason) {
        $basePath = $this.Config.Destinations.Quarantine.Path

        # Grund nach Fehler-Typ gruppieren
        $reasonFolder = switch -Regex ($Reason) {
            "corrupt|checksum|validation" { "CorruptFiles" }
            "permission|access|lock" { "AccessDenied" }
            "disk|space|full" { "DiskFull" }
            "network|connection" { "NetworkError" }
            default { "UnknownError" }
        }

        # Datum-basierte Ordnerstruktur
        $dateFolder = Get-Date -Format "yyyy-MM-dd"
        $targetDir = Join-Path $basePath $reasonFolder
        $targetDir = Join-Path $targetDir $dateFolder

        # Original-Pfadstruktur beibehalten für Debugging
        $watchFolder = $this.Config.WatchFolders[0].Path
        $relativePath = $File.DirectoryName.Replace($watchFolder, "").TrimStart("\")

        if ($relativePath) {
            $targetDir = Join-Path $targetDir $relativePath
        }

        return Join-Path $targetDir $File.Name
    }
    
    [string] SanitizePathForBOX([string]$Path) {
        # BOX-spezifische Sonderzeichen-Bereinigung
        $sanitized = $Path
        
        # % → _
        $sanitized = $sanitized.Replace("%", "_")
        
        # Weitere problematische Zeichen für BOX
        $sanitized = $sanitized.Replace("&", "_")
        $sanitized = $sanitized.Replace("#", "_")
        $sanitized = $sanitized.Replace("@", "_")
        $sanitized = $sanitized.Replace("!", "_")
        $sanitized = $sanitized.Replace("$", "_")
        $sanitized = $sanitized.Replace("^", "_")
        $sanitized = $sanitized.Replace("(", "_")
        $sanitized = $sanitized.Replace(")", "_")
        $sanitized = $sanitized.Replace("[", "_")
        $sanitized = $sanitized.Replace("]", "_")
        $sanitized = $sanitized.Replace("{", "_")
        $sanitized = $sanitized.Replace("}", "_")
        $sanitized = $sanitized.Replace("+", "_")
        $sanitized = $sanitized.Replace("=", "_")
        
        # Mehrfache Unterstriche reduzieren
        while ($sanitized.Contains("__")) {
            $sanitized = $sanitized.Replace("__", "_")
        }
        
        # Führende/nachfolgende Unterstriche entfernen
        $sanitized = $sanitized.Trim("_")
        
        return $sanitized
    }
    
    # Hilfsmethode: Prüft ob Pfad ein Netzwerkpfad ist
    [bool] IsNetworkPath([string]$Path) {
        # UNC-Pfad
        if ($Path -match '^\\\\') {
            return $true
        }
        
        # Mapped Network Drive
        $driveLetter = Split-Path -Qualifier $Path -ErrorAction SilentlyContinue
        if ($driveLetter) {
            try {
                $drive = Get-PSDrive -Name $driveLetter.TrimEnd(':') -ErrorAction SilentlyContinue
                if ($drive -and $drive.Provider.Name -eq 'FileSystem') {
                    $driveInfo = [System.IO.DriveInfo]::new($driveLetter)
                    return $driveInfo.DriveType -eq [System.IO.DriveType]::Network
                }
            } catch {
                # Ignore
            }
        }
        return $false
    }
    
    [void] TransferFile([System.IO.FileInfo]$File, [string]$Destination, [string]$DestinationType) {
        $maxRetries = 3
        $retryDelay = 2  # Sekunden
        $attempt = 0
        
        # Mehr Retries für Netzwerkpfade
        if ($this.IsNetworkPath($File.FullName) -or $this.IsNetworkPath($Destination)) {
            $maxRetries = 5
            $retryDelay = 5
        }
        
        while ($attempt -lt $maxRetries) {
            $attempt++
            try {
                $this.TransferFileInternal($File, $Destination, $DestinationType, $attempt)
                return  # Erfolg - beenden
            } catch {
                $errorMessage = $_.Exception.Message
                
                # Prüfen ob wiederholbar (Netzwerkfehler, Timeout, etc.)
                $isRetryable = $errorMessage -match 'network|timeout|access denied|being used|locked|unavailable|cannot access|connection' -or 
                               $_.Exception -is [System.IO.IOException]
                
                if ($attempt -lt $maxRetries -and $isRetryable) {
                    $waitTime = $retryDelay * [Math]::Pow(2, $attempt - 1)  # Exponential backoff
                    $this.Logger.Warning("Transfer fehlgeschlagen (Versuch $attempt/$maxRetries), wiederhole in ${waitTime}s...", @{
                        "File" = $File.FullName
                        "Error" = $errorMessage
                    })
                    Start-Sleep -Seconds $waitTime
                } else {
                    # Nicht wiederholbar oder max Retries erreicht
                    $this.Logger.Error("Transfer endgültig fehlgeschlagen nach $attempt Versuchen", @{
                        "File" = $File.FullName
                        "Error" = $errorMessage
                    })
                    
                    # Operation als fehlerhaft markieren
                    if ($this.OperationTracker) {
                        $activeOps = $this.OperationTracker.GetActiveOperations()
                        $operation = $activeOps | Where-Object { $_.FilePath -eq $File.FullName } | Select-Object -First 1
                        if ($operation) {
                            $this.OperationTracker.UpdateOperation($operation.Id, "error", -1, "Transfer failed after $attempt attempts: $errorMessage")
                        }
                    }
                    
                    # Bei Transfer-Fehlern Datei in Quarantäne verschieben
                    $this.RouteToQuarantine($File, "Transfer failed after $attempt attempts: $errorMessage")
                    return
                }
            }
        }
    }
    
    # Interne Transfer-Methode (ohne Retry-Logik)
    [void] TransferFileInternal([System.IO.FileInfo]$File, [string]$Destination, [string]$DestinationType, [int]$Attempt) {
        $this.Logger.Info("Übertrage Datei zu $DestinationType (Versuch $Attempt)", @{ 
            "Source" = $File.FullName
            "Destination" = $Destination 
        })
        
        # Prüfen ob Operation abgebrochen wurde
        if ($this.IsOperationCancelled($File.FullName)) {
            $this.Logger.Info("Operation wurde abgebrochen, überspringe Transfer", @{ "File" = $File.FullName })
            return
        }
        
        # Operation aktualisieren
        if ($this.OperationTracker) {
            $activeOps = $this.OperationTracker.GetActiveOperations()
            $operation = $activeOps | Where-Object { $_.FilePath -eq $File.FullName } | Select-Object -First 1
            if ($operation) {
                $this.OperationTracker.UpdateOperation($operation.Id, "transferring", 50)
            }
        }
        
        # Zielordner erstellen falls nicht vorhanden
        $targetDir = Split-Path $Destination -Parent
        if (-not (Test-Path $targetDir)) {
            New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
            $this.Logger.Debug("Zielordner erstellt: $targetDir", @{})
        }
        
        # Namenskonflikt prüfen
        if (Test-Path $Destination) {
            $Destination = $this.ResolveNameConflict($Destination)
            $this.Logger.Warning("Namenskonflikt aufgelöst", @{ "NewDestination" = $Destination })
        }
        
        # Atomare Move-Operation
        $tempDestination = "$Destination.tmp"
        
        # Kopieren mit Fortschrittsanzeige für große Dateien
        if ($File.Length -gt 100MB) {
            $this.CopyWithProgress($File.FullName, $tempDestination)
        } else {
            Copy-Item -Path $File.FullName -Destination $tempDestination -Force
        }
        
        # Checksumme validieren (optional bei Netzwerk)
        $skipChecksum = $false
        if ($this.Config.Performance -and $this.Config.Performance.SkipChecksumOnNetwork) {
            $skipChecksum = $this.IsNetworkPath($File.FullName) -or $this.IsNetworkPath($Destination)
            if ($skipChecksum) {
                $this.Logger.Debug("Überspringe Checksum-Validierung (Netzwerkpfad)", @{})
            }
        }
        
        if ($skipChecksum -or $this.ValidateChecksum($File.FullName, $tempDestination)) {
            # Atomares Rename
            Move-Item -Path $tempDestination -Destination $Destination -Force
            
            # Original löschen
            Remove-Item -Path $File.FullName -Force
            
            $this.Logger.Info("Datei erfolgreich übertragen", @{ 
                "Destination" = $Destination
                "Size" = $File.Length 
            })

            # History-Eintrag hinzufügen
            if ($this.StatusAPI) {
                $watchFolder = $this.Config.WatchPath
                $destFolderName = Split-Path -Leaf $Destination
                $this.StatusAPI.AddHistoryEntry($File.Name, $watchFolder, $destFolderName)
            }
            
            # Operation abschließen
            if ($this.OperationTracker) {
                $activeOps = $this.OperationTracker.GetActiveOperations()
                $operation = $activeOps | Where-Object { $_.FilePath -eq $File.FullName } | Select-Object -First 1
                if ($operation) {
                    $this.OperationTracker.CompleteOperation($operation.Id, "transferred_to_$($DestinationType.ToLower())")
                }
            }
        } else {
            # Checksum-Fehler
            Remove-Item -Path $tempDestination -Force -ErrorAction SilentlyContinue
            throw "Checksumme-Validierung fehlgeschlagen"
        }
    }
    
    [string] ResolveNameConflict([string]$Destination) {
        $directory = Split-Path $Destination -Parent
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($Destination)
        $extension = [System.IO.Path]::GetExtension($Destination)
        
        $counter = 1
        $newDestination = ""
        do {
            $newName = "$baseName`_$counter$extension"
            $newDestination = Join-Path $directory $newName
            $counter++
        } while (Test-Path $newDestination)
        
        return $newDestination
    }
    
    [void] CopyWithProgress([string]$Source, [string]$Destination) {
        $bufferSize = 1MB
        $sourceStream = [System.IO.File]::OpenRead($Source)
        $destStream = [System.IO.File]::Create($Destination)
        
        try {
            $buffer = New-Object byte[] $bufferSize
            $totalBytes = $sourceStream.Length
            $copiedBytes = 0
            
            while ($copiedBytes -lt $totalBytes) {
                $bytesRead = $sourceStream.Read($buffer, 0, $bufferSize)
                $destStream.Write($buffer, 0, $bytesRead)
                $copiedBytes += $bytesRead
                
                # Progress alle 10MB loggen
                if ($copiedBytes % (10MB) -eq 0) {
                    $percent = [math]::Round(($copiedBytes / $totalBytes) * 100, 1)
                    $this.Logger.Debug("Transfer-Fortschritt: $percent%", @{})
                }
            }
        } finally {
            $sourceStream.Close()
            $destStream.Close()
        }
    }
    
    [bool] ValidateChecksum([string]$Source, [string]$Destination) {
        try {
            # Verwende .NET direkt statt Get-FileHash (für Kompatibilität)
            $sha256 = [System.Security.Cryptography.SHA256]::Create()
            
            $sourceStream = [System.IO.File]::OpenRead($Source)
            $sourceHash = [BitConverter]::ToString($sha256.ComputeHash($sourceStream)).Replace("-", "")
            $sourceStream.Close()
            
            $destStream = [System.IO.File]::OpenRead($Destination)
            $destHash = [BitConverter]::ToString($sha256.ComputeHash($destStream)).Replace("-", "")
            $destStream.Close()
            
            $sha256.Dispose()
            
            return $sourceHash -eq $destHash
        } catch {
            $this.Logger.Warning("Checksumme-Validierung fehlgeschlagen: $($_.Exception.Message)", @{})
            return $false
        }
    }

    # CustomTabs Routing
    [bool] TryRouteCustomTab([System.IO.FileInfo]$File) {
        try {
            # Prüfe ob CustomTabs in Config existieren
            if (-not $this.Config.PSObject.Properties.Name -contains "CustomTabs" -or 
                -not $this.Config.CustomTabs -or 
                $this.Config.CustomTabs.Count -eq 0) {
                return $false
            }

            $this.Logger.Debug("Prüfe CustomTabs für: $($File.FullName)", @{})
            
            foreach ($tab in $this.Config.CustomTabs) {
                # Prüfe Nachtverarbeitung Zeitfenster für diesen Tab
                if (-not $this.IsInNightBatchWindow($tab)) {
                    $this.Logger.Debug("Tab '$($tab.Name)' ist nicht im Nachtverarbeitungsfenster - übersprungen", @{})
                    continue
                }
                
                # Prüfe ob diese Datei zum WatchFolder dieses Tabs gehört
                # TODO: Implement WatchFolder matching wenn mehrere Tabs mit unterschiedlichen Ordnern existieren
                
                if (-not $tab.Formats -or $tab.Formats.PSObject.Properties.Count -eq 0) {
                    continue
                }

                # Durchsuche alle Destinations in diesem Tab
                foreach ($destName in $tab.Formats.PSObject.Properties.Name) {
                    $formats = $tab.Formats.$destName
                    $destination = $tab.Destinations.$destName
                    
                    # Prüfe Format-Match
                    $formatMatches = $this.CheckFormatMatch($File, $formats)
                    
                    # Prüfe Text-Filter Match
                    $textMatches = $true
                    if ($destination.PSObject.Properties.Name -contains "TextFilter" -and 
                        $destination.TextFilter -and 
                        -not [string]::IsNullOrWhiteSpace($destination.TextFilter)) {
                        $textMatches = $this.CheckTextFilterMatch($File, $destination.TextFilter, $destination.CaseSensitive)
                    }

                    # Format oder Text muss passen
                    if ($formatMatches -or $textMatches) {
                        # Prüfe Ignore-Flag
                        if ($destination.PSObject.Properties.Name -contains "IsIgnore" -and $destination.IsIgnore) {
                            $this.Logger.Info("Datei ignoriert (IsIgnore gesetzt): $($File.FullName)", @{ "Destination" = $destName })
                            # Datei löschen
                            try {
                                Remove-Item -Path $File.FullName -Force
                                $this.Logger.Info("Datei gelöscht: $($File.FullName)", @{})
                            } catch {
                                $this.Logger.Warning("Konnte Datei nicht löschen: $($_.Exception.Message)", @{})
                            }
                            return $true
                        }

                        # Route zur Destination
                        $destPath = $destination.Path
                        if (-not (Test-Path $destPath)) {
                            New-Item -ItemType Directory -Path $destPath -Force | Out-Null
                        }

                        $this.TransferFile($File, $destPath, "CustomTab_$($tab.Name)_$destName")
                        return $true
                    }
                }

                # Prüfe "Restliche Dateien" Handling
                # Das wird implementiert wenn alle anderen Filters durchlaufen sind
            }

            return $false
        } catch {
            $this.Logger.Error("Fehler beim CustomTab Routing: $($_.Exception.Message)", @{ "File" = $File.FullName })
            return $false
        }
    }

    [bool] CheckFormatMatch([System.IO.FileInfo]$File, [array]$Formats) {
        if (-not $Formats -or $Formats.Count -eq 0) {
            return $false
        }

        $fileExtension = $File.Extension.ToLower()
        
        foreach ($format in $Formats) {
            $formatLower = $format.ToLower()
            # Stelle sicher, dass Format mit Punkt beginnt
            if (-not $formatLower.StartsWith(".")) {
                $formatLower = ".$formatLower"
            }
            
            if ($fileExtension -eq $formatLower) {
                $this.Logger.Debug("Format-Match: $fileExtension", @{})
                return $true
            }
        }
        
        return $false
    }

    [bool] CheckTextFilterMatch([System.IO.FileInfo]$File, [string]$TextFilter, [bool]$CaseSensitive = $false) {
        try {
            $fileName = $File.BaseName

            if ($CaseSensitive) {
                return $fileName -match $TextFilter
            } else {
                return $fileName -match "(?i)$TextFilter"
            }
        } catch {
            $this.Logger.Warning("Text-Filter Error: $($_.Exception.Message)", @{})
            return $false
        }
    }

    [bool] IsInNightBatchWindow([hashtable]$TabConfig) {
        try {
            # Prüfe ob Nachtverarbeitung für diesen Tab aktiviert ist
            if (-not $TabConfig.PSObject.Properties.Name -contains "NightBatchEnabled" -or 
                -not $TabConfig.NightBatchEnabled) {
                # Nachtverarbeitung deaktiviert - 24/7 Verarbeitung
                return $true
            }

            $currentTime = (Get-Date).TimeOfDay
            $startTimeStr = $TabConfig.NightBatchStartTime -split ":"
            $endTimeStr = $TabConfig.NightBatchEndTime -split ":"

            $startTime = [TimeSpan]::new([int]$startTimeStr[0], [int]$startTimeStr[1], 0)
            $endTime = [TimeSpan]::new([int]$endTimeStr[0], [int]$endTimeStr[1], 0)

            # Handle case where end time is before start time (e.g., 20:00 to 06:00 = crosses midnight)
            if ($startTime -lt $endTime) {
                # Same day window (e.g., 08:00 to 17:00)
                return $currentTime -ge $startTime -and $currentTime -lt $endTime
            } else {
                # Crosses midnight (e.g., 20:00 to 06:00)
                return $currentTime -ge $startTime -or $currentTime -lt $endTime
            }
        } catch {
            $this.Logger.Warning("Error in IsInNightBatchWindow: $($_.Exception.Message)", @{})
            # Bei Fehler: erlaube Verarbeitung
            return $true
        }
    }

    [bool] IsInNightBatchWindowGlobal() {
        try {
            # Prüfe ob Nachtverarbeitung in globalen Options aktiviert ist
            if (-not $this.Config.PSObject.Properties.Name -contains "Options" -or 
                -not $this.Config.Options.PSObject.Properties.Name -contains "NightBatchEnabled" -or 
                -not $this.Config.Options.NightBatchEnabled) {
                # Nachtverarbeitung deaktiviert - 24/7 Verarbeitung
                return $true
            }

            $currentTime = (Get-Date).TimeOfDay
            $startTimeStr = $this.Config.Options.NightBatchStartTime -split ":"
            $endTimeStr = $this.Config.Options.NightBatchEndTime -split ":"

            $startTime = [TimeSpan]::new([int]$startTimeStr[0], [int]$startTimeStr[1], 0)
            $endTime = [TimeSpan]::new([int]$endTimeStr[0], [int]$endTimeStr[1], 0)

            # Handle case where end time is before start time (e.g., 20:00 to 06:00 = crosses midnight)
            if ($startTime -lt $endTime) {
                # Same day window (e.g., 08:00 to 17:00)
                return $currentTime -ge $startTime -and $currentTime -lt $endTime
            } else {
                # Crosses midnight (e.g., 20:00 to 06:00)
                return $currentTime -ge $startTime -or $currentTime -lt $endTime
            }
        } catch {
            $this.Logger.Warning("Error in IsInNightBatchWindowGlobal: $($_.Exception.Message)", @{})
            # Bei Fehler: erlaube Verarbeitung
            return $true
        }
    }
}

