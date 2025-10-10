class NightBatchProcessor {
    [Logger]$Logger
    [hashtable]$Config
    [FormatClassifier]$Classifier
    [RoutingEngine]$RoutingEngine
    
    NightBatchProcessor([Logger]$Logger, [hashtable]$Config, [FormatClassifier]$Classifier, [RoutingEngine]$RoutingEngine) {
        $this.Logger = $Logger
        $this.Config = $Config
        $this.Classifier = $Classifier
        $this.RoutingEngine = $RoutingEngine
    }
    
    [void] ProcessNightFolder() {
        if (-not $this.IsProcessingWindow()) {
            $this.Logger.Info("Außerhalb des Verarbeitungsfensters")
            return
        }
        
        $nightPath = $this.Config.Destinations.Night.Path
        if (-not (Test-Path $nightPath)) {
            $this.Logger.Warning("Night-Ordner nicht gefunden: $nightPath")
            return
        }
        
        $this.Logger.Info("Starte Nachtverarbeitung: $nightPath")
        
        $files = Get-ChildItem -Path $nightPath -File -Recurse | Where-Object { $_.LastWriteTime -lt (Get-Date).AddHours(-1) }
        $this.Logger.Info("Gefunden: $($files.Count) Dateien zur Verarbeitung")
        
        $processed = 0
        $errors = 0
        
        foreach ($file in $files) {
            try {
                $this.ProcessFile($file)
                $processed++
                
                if ($processed % 100 -eq 0) {
                    $this.Logger.Info("Fortschritt: $processed/$($files.Count) Dateien verarbeitet")
                }
            } catch {
                $errors++
                $this.Logger.Error("Fehler bei Datei: $($file.FullName) - $($_.Exception.Message)")
            }
        }
        
        $this.Logger.Info("Nachtverarbeitung abgeschlossen: $processed verarbeitet, $errors Fehler")
    }
    
    [bool] IsProcessingWindow() {
        $now = Get-Date
        $startTime = [DateTime]::Parse($this.Config.Destinations.Night.ProcessingWindow.Start)
        $endTime = [DateTime]::Parse($this.Config.Destinations.Night.ProcessingWindow.End)
        
        $currentTime = $now.TimeOfDay
        
        if ($startTime.TimeOfDay -gt $endTime.TimeOfDay) {
            # Über Mitternacht (z.B. 20:00 - 06:00)
            return $currentTime -ge $startTime.TimeOfDay -or $currentTime -le $endTime.TimeOfDay
        } else {
            # Innerhalb eines Tages
            return $currentTime -ge $startTime.TimeOfDay -and $currentTime -le $endTime.TimeOfDay
        }
    }
    
    [void] ProcessFile([System.IO.FileInfo]$File) {
        $category = $this.Classifier.ClassifyFile($File)
        
        if ($category -ne "UNKNOWN") {
            $this.Logger.Info("Datei neu klassifiziert als $category", @{ "File" = $File.FullName })
            $this.RoutingEngine.RouteFile($File)
        } else {
            $this.Logger.Debug("Datei bleibt unbekannt: $($File.FullName)")
        }
    }
}