class RoutingEngine {
    [Logger]$Logger
    [hashtable]$Config
    [FormatClassifier]$Classifier
    [OperationTracker]$OperationTracker
    
    RoutingEngine([Logger]$Logger, [hashtable]$Config, [FormatClassifier]$Classifier) {
        $this.Logger = $Logger
        $this.Config = $Config
        $this.Classifier = $Classifier
        $this.OperationTracker = $null  # Wird später gesetzt
    }
    
    [void] SetOperationTracker([OperationTracker]$OperationTracker) {
        $this.OperationTracker = $OperationTracker
        $this.Logger.Info("OperationTracker wurde gesetzt", @{})
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
            $this.Logger.Info("Route Datei: $($File.FullName)")
            
            # Operation aktualisieren (Status: analyzing -> processing)
            if ($this.OperationTracker) {
                # Finde Operation für diese Datei
                $activeOps = $this.OperationTracker.GetActiveOperations()
                $operation = $activeOps | Where-Object { $_.FilePath -eq $File.FullName } | Select-Object -First 1
                if ($operation) {
                    $this.OperationTracker.UpdateOperation($operation.Id, "processing", 25)
                }
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
                    $this.Logger.Debug("System-Datei ignoriert: $($File.FullName)")
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

            $destination = $this.BuildBOXPath($File)
            $this.TransferFile($File, $destination, "BOX")

        } catch {
            $this.Logger.Error("Fehler beim BOX-Routing: $($_.Exception.Message)", @{ "File" = $File.FullName })
            $this.RouteToQuarantine($File, "BOX-Routing failed: $($_.Exception.Message)")
        }
    }
    
    [void] RouteToQuarantine([System.IO.FileInfo]$File, [string]$Reason) {
        try {
            $destination = $this.BuildQuarantinePath($File, $Reason)
            $this.TransferFile($File, $destination, "Quarantine")

            $this.Logger.Warning("Datei in Quarantäne verschoben", @{
                "File" = $File.FullName
                "Reason" = $Reason
                "QuarantinePath" = $destination
            })

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
    
    [void] TransferFile([System.IO.FileInfo]$File, [string]$Destination, [string]$DestinationType) {
        try {
            $this.Logger.Info("Übertrage Datei zu $DestinationType", @{ 
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
                $this.Logger.Debug("Zielordner erstellt: $targetDir")
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
            
            # Checksumme validieren
            if ($this.ValidateChecksum($File.FullName, $tempDestination)) {
                # Atomares Rename
                Move-Item -Path $tempDestination -Destination $Destination -Force
                
                # Original löschen
                Remove-Item -Path $File.FullName -Force
                
                $this.Logger.Info("Datei erfolgreich übertragen", @{ 
                    "Destination" = $Destination
                    "Size" = $File.Length 
                })
                
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
            
        } catch {
            $this.Logger.Error("Fehler beim Dateitransfer: $($_.Exception.Message)", @{ 
                "File" = $File.FullName
                "Destination" = $Destination 
            })
            
            # Operation als fehlerhaft markieren
            if ($this.OperationTracker) {
                $activeOps = $this.OperationTracker.GetActiveOperations()
                $operation = $activeOps | Where-Object { $_.FilePath -eq $File.FullName } | Select-Object -First 1
                if ($operation) {
                    $this.OperationTracker.UpdateOperation($operation.Id, "error", -1, $_.Exception.Message)
                }
            }
            
            # Bei Transfer-Fehlern Datei in Quarantäne verschieben
            $this.RouteToQuarantine($File, "Transfer failed: $($_.Exception.Message)")
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
                    $this.Logger.Debug("Transfer-Fortschritt: $percent%")
                }
            }
        } finally {
            $sourceStream.Close()
            $destStream.Close()
        }
    }
    
    [bool] ValidateChecksum([string]$Source, [string]$Destination) {
        try {
            $sourceHash = Get-FileHash -Path $Source -Algorithm SHA256
            $destHash = Get-FileHash -Path $Destination -Algorithm SHA256
            
            return $sourceHash.Hash -eq $destHash.Hash
        } catch {
            $this.Logger.Warning("Checksumme-Validierung fehlgeschlagen: $($_.Exception.Message)")
            return $false
        }
    }
}