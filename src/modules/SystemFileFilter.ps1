class SystemFileFilter {
    [hashtable]$CameraSystemPatterns
    [hashtable]$OSSystemPatterns
    [Logger]$Logger
    
    SystemFileFilter([Logger]$Logger) {
        $this.Logger = $Logger
        $this.InitializePatterns()
    }
    
    [void] InitializePatterns() {
        $this.CameraSystemPatterns = @{
            # Sony Kamera-Systemdateien
            "Sony" = @("*.BIM", "*.CPI", "*.PEK", "GENERAL/*.XML", "CLIP/*.XML")
            # Canon Kamera-Systemdateien  
            "Canon" = @("*.CIF", "*.CPF", "*.CTG", "CANON*")
            # Panasonic Kamera-Systemdateien
            "Panasonic" = @("*.IDX", "*.PGI", "PRIVATE/*")
            # RED Kamera-Systemdateien
            "RED" = @("*.RMD", "*.RSX", "*.R3D.bak")
        }
        
        $this.OSSystemPatterns = @{
            "Windows" = @("Thumbs.db", "desktop.ini", "*.tmp", "*.log", "~*", "*.lnk")
            "MacOS" = @(".DS_Store", "._*", ".Spotlight-*", ".Trashes", ".fseventsd")
            "Linux" = @(".directory", "*.swp", "*.swo", "*~")
        }
    }
    
    [bool] IsSystemFile([System.IO.FileInfo]$File) {
        $fileName = $File.Name
        $relativePath = $File.DirectoryName
        
        # Kamera-Systemdateien prüfen
        foreach ($camera in $this.CameraSystemPatterns.Keys) {
            foreach ($pattern in $this.CameraSystemPatterns[$camera]) {
                if ($fileName -like $pattern -or $relativePath -like "*$pattern*") {
                    $this.Logger.Debug("Kamera-Systemdatei erkannt: $camera", @{ "File" = $File.FullName })
                    return $true
                }
            }
        }
        
        # OS-Systemdateien prüfen
        foreach ($os in $this.OSSystemPatterns.Keys) {
            foreach ($pattern in $this.OSSystemPatterns[$os]) {
                if ($fileName -like $pattern) {
                    $this.Logger.Debug("OS-Systemdatei erkannt: $os", @{ "File" = $File.FullName })
                    return $true
                }
            }
        }
        
        return $false
    }
}