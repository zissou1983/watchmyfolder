class Logger {
    [string]$LogPath
    [string]$LogLevel
    [int]$MaxSizeMB
    [int]$MaxFiles
    
    Logger([string]$Path, [string]$Level) {
        $this.LogPath = $Path
        $this.LogLevel = $Level
        $this.MaxSizeMB = 100
        $this.MaxFiles = 10
        $this.Initialize()
    }
    
    [void] Initialize() {
        if ([string]::IsNullOrEmpty($this.LogPath)) {
            throw "LogPath darf nicht leer sein"
        }
        
        $logDir = Split-Path $this.LogPath -Parent
        if ([string]::IsNullOrEmpty($logDir)) {
            $logDir = "."
        }
        
        if (-not (Test-Path $logDir)) {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }
    }
    
    [void] Log([string]$Level, [string]$Message, [hashtable]$Context = @{}) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $contextStr = if ($Context.Count -gt 0) { " | Context: $($Context | ConvertTo-Json -Compress)" } else { "" }
        $logEntry = "[$timestamp] [$Level] $Message$contextStr"
        
        # Rotation prüfen
        $this.CheckRotation()
        
        # Log schreiben
        Add-Content -Path $this.LogPath -Value $logEntry -Encoding UTF8
        
        # Console Output für Debug
        if ($Level -eq "Error" -or $Level -eq "Warning") {
            Write-Host $logEntry -ForegroundColor $(if ($Level -eq "Error") { "Red" } else { "Yellow" })
        }
    }
    
    [void] CheckRotation() {
        if (Test-Path $this.LogPath) {
            $fileInfo = Get-Item $this.LogPath
            if ($fileInfo.Length -gt ($this.MaxSizeMB * 1MB)) {
                $this.RotateLog()
            }
        }
    }
    
    [void] RotateLog() {
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($this.LogPath)
        $extension = [System.IO.Path]::GetExtension($this.LogPath)
        $directory = Split-Path $this.LogPath -Parent
        
        # Alte Logs verschieben
        for ($i = $this.MaxFiles - 1; $i -gt 0; $i--) {
            $oldFile = Join-Path $directory "$baseName.$i$extension"
            $newFile = Join-Path $directory "$baseName.$($i + 1)$extension"
            
            if (Test-Path $oldFile) {
                if ($i -eq ($this.MaxFiles - 1)) {
                    Remove-Item $oldFile -Force
                } else {
                    Move-Item $oldFile $newFile -Force
                }
            }
        }
        
        # Aktuelles Log zu .1 verschieben
        if (Test-Path $this.LogPath) {
            $rotatedFile = Join-Path $directory "$baseName.1$extension"
            Move-Item $this.LogPath $rotatedFile -Force
        }
    }
    
    [void] Info([string]$Message, [hashtable]$Context = @{}) {
        $this.Log("Info", $Message, $Context)
    }
    
    [void] Warning([string]$Message, [hashtable]$Context = @{}) {
        $this.Log("Warning", $Message, $Context)
    }
    
    [void] Error([string]$Message, [hashtable]$Context = @{}) {
        $this.Log("Error", $Message, $Context)
    }
    
    [void] Debug([string]$Message, [hashtable]$Context = @{}) {
        if ($this.LogLevel -eq "Debug") {
            $this.Log("Debug", $Message, $Context)
        }
    }
}