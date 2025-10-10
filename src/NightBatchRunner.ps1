# Standalone Runner für Nachtverarbeitung (für Scheduled Task)
param(
    [string]$ConfigPath = ".\config\config.json"
)

# Module laden
. "$PSScriptRoot\modules\Logger.ps1"
. "$PSScriptRoot\modules\FormatClassifier.ps1"
. "$PSScriptRoot\modules\RoutingEngine.ps1"
. "$PSScriptRoot\modules\NightBatch.ps1"

try {
    # Konfiguration laden
    $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json -AsHashtable
    
    # Logger initialisieren
    $logger = [Logger]::new($config.Logging.Path, $config.Logging.Level)
    $logger.Info("Nachtverarbeitung gestartet")
    
    # Komponenten initialisieren
    $classifier = [FormatClassifier]::new($logger)
    $routingEngine = [RoutingEngine]::new($logger, $config, $classifier)
    $nightProcessor = [NightBatchProcessor]::new($logger, $config, $classifier, $routingEngine)
    
    # Verarbeitung starten
    $nightProcessor.ProcessNightFolder()
    
    $logger.Info("Nachtverarbeitung abgeschlossen")
    
} catch {
    if ($logger) {
        $logger.Error("Kritischer Fehler in Nachtverarbeitung: $($_.Exception.Message)")
    } else {
        Write-Error "Kritischer Fehler: $($_.Exception.Message)"
    }
    exit 1
}