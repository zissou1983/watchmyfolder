# Hauptservice für das Watch Folder System
param(
    [string]$ConfigPath,
    [switch]$Debug
)

# Module laden (vor Klassendefinition    # StatusAPI und Service parallel laufen lassen
    try {
        # StatusAPI läuft bereits in Job
        
        # Hauptschleife - Service läuft kontinuierlich
        while ($Service.IsRunning) {
            Start-Sleep -Seconds 1
        }
        
    } catch {
        Write-Host "Fehler in Hauptschleife: $($_.Exception.Message)" -ForegroundColor Red
    } finally {
        # StatusAPI Job stoppen
        if ($Service.StatusAPIJob) {
            Stop-Job $Service.StatusAPIJob -ErrorAction SilentlyContinue
            Remove-Job $Service.StatusAPIJob -ErrorAction SilentlyContinue
        }
        Stop-WatchFolderService -Service $Service
    }SScriptRoot\modules\Logger.ps1"
    . "$PSScriptRoot\modules\SystemFileFilter.ps1" 
    . "$PSScriptRoot\modules\FormatClassifier.ps1"
    . "$PSScriptRoot\modules\PerformanceMonitor.ps1"
    . "$PSScriptRoot\modules\OperationTracker.ps1"  # Vor RoutingEngine laden
    . "$PSScriptRoot\modules\WatchEngine.ps1"
    . "$PSScriptRoot\modules\RoutingEngine.ps1"
    . "$PSScriptRoot\api\StatusAPI.ps1"
    
    Start-Sleep -Milliseconds 100
} catch {
    Write-Error "Fehler beim Laden der Module: $($_.Exception.Message)"
    exit 1
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
    $service.Config = @{}
    $configObj.PSObject.Properties | ForEach-Object {
        $service.Config[$_.Name] = $_.Value
    }
    
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
    
    # Status API in separatem Job starten (mit ScriptBlock der alles neu lädt)
    $service.StatusAPIJob = Start-Job -ScriptBlock {
        param($scriptRoot, $loggerPath, $configPath, $port)
        
        # Module und Klassen neu laden im Job
        . "$scriptRoot\modules\Logger.ps1"
        . "$scriptRoot\api\StatusAPI.ps1"
        
        $logger = [Logger]::new($loggerPath, "Info")
        $config = Get-Content $configPath | ConvertFrom-Json
        $service = @{ Config = $config; IsRunning = $true; WatchEngine = $null; OperationTracker = $null }
        $api = [StatusAPI]::new($logger, $service, $port)
        
        try {
            $api.Start()
        } catch {
            Write-Host "StatusAPI Fehler: $($_.Exception.Message)" -ForegroundColor Red
        }
    } -ArgumentList $PSScriptRoot, "$PSScriptRoot\..\logs\statusapi.log", $ConfigPath, 8082
    
    # Callback setzen
    $service.WatchEngine.FileReadyCallback = { 
        param($File)
        if (-not $service.SystemFilter.IsSystemFile($File)) {
            # Operation starten
            $service.OperationTracker.StartOperation($File.FullName, "file_processing")
            $service.RoutingEngine.RouteFile($File)
        }
    }
    
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
            Write-Host "Ueberspringe Ueberwachung fuer: $($watchFolder.Path) (Debug-Modus)" -ForegroundColor Yellow
            # try {
            #     $Service.WatchEngine.Start($watchFolder.Path)
            # } catch {
            #     Write-Host "Fehler beim Starten der Überwachung für $($watchFolder.Path): $($_.Exception.Message)" -ForegroundColor Red
            #     # Bei Fehler trotzdem fortfahren
            # }
        }
    }
    
    $Service.IsRunning = $true
    Write-Host "Watch Folder Service erfolgreich gestartet" -ForegroundColor Green
    Write-Host "Service läuft kontinuierlich. Verwenden Sie Ctrl+C zum Beenden." -ForegroundColor Cyan
    
    # StatusAPI und Service parallel laufen lassen
    try {
        # StatusAPI läuft bereits im Hauptthread
        
        # Hauptschleife - Service läuft kontinuierlich
        while ($Service.IsRunning) {
            Start-Sleep -Seconds 1
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
