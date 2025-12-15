class FormatClassifier {
    [hashtable]$FormatDatabase
    [Logger]$Logger
    [hashtable]$Config
    
    FormatClassifier([Logger]$Logger) {
        $this.Logger = $Logger
        $this.Config = @{}
        $this.InitializeFormatDatabase()
    }
    
    # Konstruktor mit Config-Parameter für spätere Initialisierung
    FormatClassifier([Logger]$Logger, [hashtable]$Config) {
        $this.Logger = $Logger
        $this.Config = $Config
        $this.InitializeFormatDatabase()
    }
    
    [void] InitializeFormatDatabase() {
        # Standard-Format-Datenbank (Fallback)
        $defaultFormats = @{
            "MAM" = @(".mxf", ".mov", ".mp4", ".avi", ".mkv", ".m4v", ".wav", ".aiff", ".flac", ".mp3", ".aac")
            "BOX" = @(".pdf", ".doc", ".docx", ".xls", ".xlsx", ".ppt", ".pptx", ".txt")
            "SYSTEM" = @(".tmp", ".log", ".cache", ".db", ".ini", ".sys", ".bim", ".cpi", ".pek", ".xmp", ".xml")
        }
        
        # Formate aus Konfiguration laden, falls verfügbar
        $configFormats = if ($this.Config -and $this.Config.ContainsKey("Formats") -and $this.Config.Formats) {
            $this.Config.Formats
        } else {
            $defaultFormats
        }
        
        $this.FormatDatabase = @{}
        
        # MAM Formate
        $mamFormats = if ($configFormats -is [hashtable]) { $configFormats["MAM"] } else { $configFormats.MAM }
        if ($mamFormats) {
            $this.FormatDatabase["Video_MAM"] = @{
                "Extensions" = $mamFormats
                "Category" = "MAM"
            }
        }
        
        # BOX Formate
        $boxFormats = if ($configFormats -is [hashtable]) { $configFormats["BOX"] } else { $configFormats.BOX }
        if ($boxFormats) {
            $this.FormatDatabase["Documents"] = @{
                "Extensions" = $boxFormats
                "Category" = "BOX"
            }
        }
        
        # SYSTEM Formate
        $sysFormats = if ($configFormats -is [hashtable]) { $configFormats["SYSTEM"] } else { $configFormats.SYSTEM }
        if ($sysFormats) {
            $this.FormatDatabase["System"] = @{
                "Extensions" = $sysFormats
                "Category" = "SYSTEM"
            }
            $this.FormatDatabase["Camera_System"] = @{
                "Extensions" = $sysFormats
                "Patterns" = @("Thumbs.db", "desktop.ini", ".DS_Store")
                "Category" = "SYSTEM"
            }
        }
        
        # MXF speziell behandeln (Magic Numbers)
        $this.FormatDatabase["MXF"] = @{
            "MagicNumbers" = @("060E2B34", "060e2b34")
            "Extensions" = @(".mxf")
            "Category" = "MAM"
        }
    }
    
    [string] ClassifyFile([System.IO.FileInfo]$File) {
        try {
            $this.Logger.Debug("Klassifiziere Datei: $($File.FullName)", @{})
            
            # System-Dateien prüfen
            if ($this.IsSystemFile($File)) {
                return "SYSTEM"
            }
            
            # MXF-Dateien haben Priorität
            if ($this.IsMXFFile($File)) {
                if ($this.ValidateMAMFile($File)) {
                    return "MAM"
                }
            }
            
            # Extension-basierte Klassifizierung
            $extension = $File.Extension.ToLower()
            
            foreach ($format in $this.FormatDatabase.Keys) {
                $formatInfo = $this.FormatDatabase[$format]
                if ($formatInfo.Extensions -contains $extension) {
                    $this.Logger.Debug("Datei klassifiziert als: $($formatInfo.Category)", @{})
                    return $formatInfo.Category
                }
            }
            
            $this.Logger.Warning("Unbekanntes Dateiformat: $extension", @{ "File" = $File.FullName })
            return "UNKNOWN"
            
        } catch {
            $this.Logger.Error("Fehler bei Dateiklassifizierung: $($_.Exception.Message)", @{ "File" = $File.FullName })
            return "UNKNOWN"
        }
    }
    
    [bool] IsMXFFile([System.IO.FileInfo]$File) {
        if ($File.Extension.ToLower() -ne ".mxf") {
            return $false
        }
        
        try {
            # Magic Number prüfen
            $bytes = [System.IO.File]::ReadAllBytes($File.FullName) | Select-Object -First 4
            $magicHex = [System.BitConverter]::ToString($bytes).Replace("-", "").ToLower()
            
            return $this.FormatDatabase.MXF.MagicNumbers -contains $magicHex
        } catch {
            $this.Logger.Warning("Konnte MXF Magic Number nicht prüfen: $($_.Exception.Message)", @{ "File" = $File.FullName })
            return $true # Fallback auf Extension
        }
    }
    
    [bool] ValidateMAMFile([System.IO.FileInfo]$File) {
        try {
            # Grundlegende Validierung
            if ($File.Length -eq 0) {
                $this.Logger.Warning("Leere MAM-Datei gefunden", @{ "File" = $File.FullName })
                return $false
            }
            
            # Minimale Dateigröße für MXF (1KB)
            if ($File.Extension.ToLower() -eq ".mxf" -and $File.Length -lt 1024) {
                $this.Logger.Warning("MXF-Datei zu klein", @{ "File" = $File.FullName; "Size" = $File.Length })
                return $false
            }
            
            # TODO: FFprobe Integration für detaillierte Validierung
            
            return $true
            
        } catch {
            $this.Logger.Error("Fehler bei MAM-Datei-Validierung: $($_.Exception.Message)", @{ "File" = $File.FullName })
            return $false
        }
    }
    
    [bool] IsSystemFile([System.IO.FileInfo]$File) {
        $fileName = $File.Name.ToLower()
        $extension = $File.Extension.ToLower()
        
        # System-Extensions prüfen
        if ($this.FormatDatabase.System.Extensions -contains $extension -or 
            $this.FormatDatabase.Camera_System.Extensions -contains $extension) {
            return $true
        }
        
        # System-Dateinamen-Patterns prüfen
        foreach ($pattern in $this.FormatDatabase.Camera_System.Patterns) {
            if ($fileName -like $pattern.ToLower()) {
                return $true
            }
        }
        
        # Versteckte Dateien (beginnen mit .)
        if ($fileName.StartsWith(".")) {
            return $true
        }
        
        return $false
    }
}