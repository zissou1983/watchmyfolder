# Hauptservice für das Watch Folder System
param(
    [string]$ConfigPath = "$PSScriptRoot\..\config\config.json",
    [switch]$Debug
)

# Module laden (vor Klassendefinition)
$requiredModules = @(
    "$PSScriptRoot\modules\Logger.ps1",
    "$PSScriptRoot\modules\SystemFileFilter.ps1",
    "$PSScriptRoot\modules\FormatClassifier.ps1",
    "$PSScriptRoot\modules\PerformanceMonitor.ps1",
    "$PSScriptRoot\modules\OperationTracker.ps1",
    "$PSScriptRoot\modules\WatchEngine.ps1",
    "$PSScriptRoot\modules\RoutingEngine.ps1",
    "$PSScriptRoot\api\StatusAPI.ps1"
)

foreach ($module in $requiredModules) {
    if (-not (Test-Path $module)) {
        Write-Error "Modul nicht gefunden: $module"
        exit 1
    }
    try {
        . $module
        Write-Host "Modul geladen: $(Split-Path $module -Leaf)" -ForegroundColor Green
    } catch {
        Write-Error "Fehler beim Laden von $module`: $($_.Exception.Message)"
        exit 1
    }
}

Start-Sleep -Milliseconds 100

# Hilfsfunktion: PSObject zu Hashtable konvertieren
function ConvertTo-Hashtable($obj) {
    $hash = @{}
    if ($obj -is [PSCustomObject]) {
        $obj.PSObject.Properties | ForEach-Object {
            if ($_.Value -is [PSCustomObject]) {
                $hash[$_.Name] = ConvertTo-Hashtable $_.Value
            } elseif ($_.Value -is [Array]) {
                $hash[$_.Name] = @()
                foreach ($item in $_.Value) {
                    if ($item -is [PSCustomObject]) {
                        $hash[$_.Name] += ConvertTo-Hashtable $item
                    } else {
                        $hash[$_.Name] += $item
                    }
                }
            } else {
                $hash[$_.Name] = $_.Value
            }
        }
    } else {
        return $obj
    }
    return $hash
}

# Service-Funktionen (ohne Klasse)
function New-WatchFolderService {
    param([string]$ConfigPath)
    
    $service = @{
        Logger = $null
        Config = $null
        SystemFilter = $null
        Classifier = $null
        WatchEngine = $null
        RoutingEngine = $null
        StatusAPI = $null
        OperationTracker = $null
        StatusAPIJob = $null
        IsRunning = $false
    }
    
    # Konfiguration laden
    if (-not (Test-Path $ConfigPath)) {
        throw "Konfigurationsdatei nicht gefunden: $ConfigPath"
    }
    
    $configContent = Get-Content -Path $ConfigPath -Raw -Encoding UTF8
    $configObj = $configContent | ConvertFrom-Json
    
    # PSCustomObject zu Hashtable konvertieren
    $service.Config = ConvertTo-Hashtable $configObj
    
    # Komponenten initialisieren
    $service.Logger = [Logger]::new($service.Config.Logging.Path, $service.Config.Logging.Level)
    Write-Host "Watch Folder Service wird initialisiert..." -ForegroundColor Green
    
    $service.SystemFilter = [SystemFileFilter]::new($service.Logger)
    $service.Classifier = [FormatClassifier]::new($service.Logger, $service.Config)
    $service.WatchEngine = [WatchEngine]::new($service.Logger, $service.Config)
    $service.RoutingEngine = [RoutingEngine]::new($service.Logger, $service.Config, $service.Classifier)
    $service.OperationTracker = [OperationTracker]::new($service.Logger)
    
    # OperationTracker mit RoutingEngine verbinden
    $service.RoutingEngine.SetOperationTracker($service.OperationTracker)
    
    # WatchEngine mit RoutingEngine verbinden
    $service.WatchEngine.FileReadyCallback = {
        param($File)
        $service.RoutingEngine.RouteFile($File)
    }
    
    # StatusAPI instanziieren
    $service.StatusAPI = [StatusAPI]::new($service.Logger, $service, 8082)
    $service.RoutingEngine.SetStatusAPI($service.StatusAPI)
    
    # StatusAPI in separatem Job starten
    $service.StatusAPIJob = Start-Job -ScriptBlock {
        param($statusAPI)
        try {
            $statusAPI.Start()
        } catch {
            Write-Host "StatusAPI Fehler: $($_.Exception.Message)" -ForegroundColor Red
        }
    } -ArgumentList $service.StatusAPI
    
    Write-Host "Alle Komponenten erfolgreich initialisiert" -ForegroundColor Green
    return $service
}

function Start-WatchFolderService {
    param($Service)
    
    if ($Service.IsRunning) {
        Write-Host "Service läuft bereits" -ForegroundColor Yellow
        return
    }
    
    Write-Host "Starte Watch Folder Service..." -ForegroundColor Green
    
    # Status API starten
    if ($Service.StatusAPIJob) {
        Write-Host "Starte Dashboard auf http://localhost:8082" -ForegroundColor Cyan
        # StatusAPI läuft bereits in Job
    }
    
    # Watch Engines starten
    foreach ($watchFolder in $Service.Config.WatchFolders) {
        if ($watchFolder.Enabled) {
            Write-Host "Starte Ueberwachung fuer: $($watchFolder.Path)" -ForegroundColor Cyan
            try {
                $Service.WatchEngine.Start($watchFolder.Path)
                Write-Host "Ueberwachung gestartet fuer: $($watchFolder.Path)" -ForegroundColor Green
            } catch {
                Write-Host "Fehler beim Starten der Ueberwachung fuer $($watchFolder.Path): $($_.Exception.Message)" -ForegroundColor Red
                # Bei Fehler trotzdem fortfahren
            }
        }
    }
    
    $Service.IsRunning = $true
    Write-Host "Watch Folder Service erfolgreich gestartet" -ForegroundColor Green
    Write-Host "Service läuft kontinuierlich. Verwenden Sie Ctrl+C zum Beenden." -ForegroundColor Cyan
    
    # Timing-Variablen für manuelle Timer-Simulation
    $lastPollingTime = Get-Date
    $lastProcessingTime = Get-Date
    $lastHealthCheckTime = Get-Date
    $pollingIntervalMs = 10000  # 10 Sekunden für Polling
    $processingIntervalMs = 5000  # 5 Sekunden für Queue-Verarbeitung
    $healthCheckIntervalMs = 60000  # 60 Sekunden für Health Check
    
    # StatusAPI und Service parallel laufen lassen
    try {
        # StatusAPI läuft bereits im Hauptthread
        
        # Hauptschleife - Service läuft kontinuierlich
        # WICHTIG: Wir rufen Timer-Funktionen DIREKT auf statt auf Events zu warten
        # Das ist ein Workaround für PowerShell Register-ObjectEvent Probleme mit Klassenmethoden
        $errorCount = 0
        while ($Service.IsRunning) {
            $now = Get-Date
            
            # Polling ausführen (alle 10 Sekunden)
            if (($now - $lastPollingTime).TotalMilliseconds -ge $pollingIntervalMs) {
                try {
                    $Service.WatchEngine.PollForChanges()
                } catch {
                    $errorCount++
                    if ($errorCount -le 3) {  # Nur erste 3 Fehler ausgeben
                        Write-Host "POLLING FEHLER: $($_.Exception.Message)" -ForegroundColor Red
                    }
                }
                $lastPollingTime = $now
            }
            
            # Queue-Verarbeitung ausführen (alle 5 Sekunden)
            if (($now - $lastProcessingTime).TotalMilliseconds -ge $processingIntervalMs) {
                try {
                    $Service.WatchEngine.ProcessQueue()
                } catch {
                    $errorCount++
                    if ($errorCount -le 3) {  # Nur erste 3 Fehler ausgeben
                        Write-Host "QUEUE FEHLER: $($_.Exception.Message)" -ForegroundColor Red
                    }
                }
                $lastProcessingTime = $now
            }
            
            # Health Check ausführen (alle 60 Sekunden)
            if (($now - $lastHealthCheckTime).TotalMilliseconds -ge $healthCheckIntervalMs) {
                if ($Service.WatchEngine.IsNetworkPath) {
                    try {
                        $Service.WatchEngine.CheckWatcherHealth()
                    } catch {
                        # Fehler beim Health Check ignorieren
                    }
                }
                $lastHealthCheckTime = $now
            }
            
            # Kurze Pause, damit CPU nicht vollständig ausgelastet wird
            Start-Sleep -Milliseconds 100
        }
        
    } finally {
        # StatusAPI Job stoppen
        if ($Service.StatusAPIJob) {
            Stop-Job $Service.StatusAPIJob -ErrorAction SilentlyContinue
            Remove-Job $Service.StatusAPIJob -ErrorAction SilentlyContinue
        }
        Stop-WatchFolderService -Service $Service
    }
}

function Stop-WatchFolderService {
    param($Service)
    
    if (-not $Service.IsRunning) {
        return
    }
    
    Write-Host "Stoppe Watch Folder Service..." -ForegroundColor Yellow
    
    if ($Service.WatchEngine) {
        $Service.WatchEngine.Stop()
    }
    
    # StatusAPI Job stoppen
    if ($Service.StatusAPIJob) {
        Stop-Job $Service.StatusAPIJob -ErrorAction SilentlyContinue
        Remove-Job $Service.StatusAPIJob -ErrorAction SilentlyContinue
    }
    
    $Service.IsRunning = $false
    Write-Host "Watch Folder Service gestoppt" -ForegroundColor Green
}

# Service starten
try {
    $service = New-WatchFolderService -ConfigPath $ConfigPath
    
    if ($Debug) {
        $service.Config.Logging.Level = "Debug"
        Write-Host "Debug-Modus aktiviert" -ForegroundColor Yellow
    }
    
    # Graceful Shutdown
    Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
        Stop-WatchFolderService -Service $service
    } | Out-Null
    
    Start-WatchFolderService -Service $service
    
} catch {
    Write-Error "Kritischer Fehler: $($_.Exception.Message)"
    exit 1
}