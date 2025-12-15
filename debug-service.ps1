# Debug-Version der WatchFolderService
$requiredModules = @(
    "$PSScriptRoot\src\modules\Logger.ps1",
    "$PSScriptRoot\src\modules\SystemFileFilter.ps1",
    "$PSScriptRoot\src\modules\FormatClassifier.ps1",
    "$PSScriptRoot\src\modules\PerformanceMonitor.ps1",
    "$PSScriptRoot\src\modules\OperationTracker.ps1",
    "$PSScriptRoot\src\modules\WatchEngine.ps1",
    "$PSScriptRoot\src\modules\RoutingEngine.ps1",
    "$PSScriptRoot\api\StatusAPI.ps1"
)

foreach ($module in $requiredModules) {
    . $module
}

$config = Get-Content "config\config.json" | ConvertFrom-Json

$logger = [Logger]::new($config.Logging.Path, $config.Logging.Level)
$classifier = [FormatClassifier]::new($logger, $config)
$watchEngine = [WatchEngine]::new($logger, $config)

Write-Host "=== DEBUG SERVICE ===" -ForegroundColor Yellow
Write-Host "WatchPath: $(($config.WatchFolders[0]).Path)" -ForegroundColor Cyan

# Starte Watch Engine
$watchEngine.Start(($config.WatchFolders[0]).Path)
Write-Host "Watch Engine gestartet" -ForegroundColor Green

# Simuliere 30 Sekunden Loop
for ($i = 0; $i -lt 30; $i++) {
    Write-Host "[$i] $(Get-Date -Format HH:mm:ss.fff): Polling..." -ForegroundColor Cyan
    $watchEngine.PollForChanges()
    
    $fileCount = $watchEngine.FileQueue.Count
    if ($fileCount -gt 0) {
        Write-Host "  >> Queue hat $fileCount Dateien!" -ForegroundColor Yellow
    }
    
    Write-Host "  >> Verarbeite Queue..." -ForegroundColor Gray
    $watchEngine.ProcessQueue()
    
    $fileCount = $watchEngine.FileQueue.Count
    if ($fileCount -gt 0) {
        Write-Host "  >> Nach Processing: Queue hat noch $fileCount Dateien" -ForegroundColor Red
    }
    
    Start-Sleep -Seconds 1
}

Write-Host "Debug abgeschlossen" -ForegroundColor Green
