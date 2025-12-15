# Minimales Debug-Skript für Watch Folder
Set-Location "e:\GitHub\watchmyfolder"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "WATCH FOLDER DEBUG TEST" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Starte neuen PowerShell-Prozess um Typ-Konflikte zu vermeiden
$scriptBlock = @'
Set-Location "e:\GitHub\watchmyfolder"

# Module laden
Write-Host "`n[1] Module laden..." -ForegroundColor Yellow
$modules = @(
    "src\modules\Logger.ps1",
    "src\modules\SystemFileFilter.ps1", 
    "src\modules\FormatClassifier.ps1",
    "src\modules\PerformanceMonitor.ps1",
    "src\modules\OperationTracker.ps1",
    "src\modules\WatchEngine.ps1",
    "src\modules\RoutingEngine.ps1"
)

foreach ($m in $modules) {
    . $m
    Write-Host "  OK: $m" -ForegroundColor Green
}

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

# Config laden
Write-Host "`n[2] Config laden..." -ForegroundColor Yellow
$configObj = Get-Content "config\config.json" -Raw | ConvertFrom-Json
$config = ConvertTo-Hashtable $configObj
Write-Host "  WatchPath: $($config.WatchFolders[0].Path)" -ForegroundColor Gray
Write-Host "  NightPath: $($config.Destinations.Night.Path)" -ForegroundColor Gray
Write-Host "  GracePeriod: $($config.WatchFolders[0].GracePeriod) Sekunden" -ForegroundColor Gray

# Komponenten erstellen
Write-Host "`n[3] Komponenten erstellen..." -ForegroundColor Yellow
$logger = [Logger]::new($config.Logging.Path, "Debug")
$classifier = [FormatClassifier]::new($logger, $config)
$watchEngine = [WatchEngine]::new($logger, $config)
$routingEngine = [RoutingEngine]::new($logger, $config, $classifier)
Write-Host "  Alle Komponenten erstellt" -ForegroundColor Green

# Callback setzen
Write-Host "`n[4] Callback verbinden..." -ForegroundColor Yellow
$watchEngine.FileReadyCallback = {
    param($File)
    Write-Host "  >>> CALLBACK AUFGERUFEN für: $($File.FullName)" -ForegroundColor Magenta
    $routingEngine.RouteFile($File)
}
Write-Host "  Callback gesetzt" -ForegroundColor Green

# WatchEngine starten
Write-Host "`n[5] WatchEngine starten..." -ForegroundColor Yellow
$watchEngine.Start($config.WatchFolders[0].Path)
Write-Host "  WatchEngine gestartet" -ForegroundColor Green

# Testdatei erstellen
Write-Host "`n[6] Testdatei erstellen..." -ForegroundColor Yellow
$testFile = "C:\Temp\Incoming\debug-test-$(Get-Random).txt"
"Test content created at $(Get-Date)" | Out-File $testFile
Write-Host "  Erstellt: $testFile" -ForegroundColor Green
$testFileName = Split-Path $testFile -Leaf

# Warte kurz
Write-Host "`n[7] Warte 2 Sekunden..." -ForegroundColor Yellow
Start-Sleep 2

# Polling auslösen
Write-Host "`n[8] Polling auslösen..." -ForegroundColor Yellow
Write-Host "  Queue vor Polling: $($watchEngine.FileQueue.Count) Dateien" -ForegroundColor Gray
$watchEngine.PollForChanges()
Write-Host "  Queue nach Polling: $($watchEngine.FileQueue.Count) Dateien" -ForegroundColor Gray

# Warte auf GracePeriod
$gracePeriod = $config.WatchFolders[0].GracePeriod
Write-Host "`n[9] Warte $($gracePeriod + 2) Sekunden (GracePeriod + 2)..." -ForegroundColor Yellow
Start-Sleep ($gracePeriod + 2)

# Nochmal Polling um sicher zu sein
Write-Host "`n[10] Erneutes Polling..." -ForegroundColor Yellow
$watchEngine.PollForChanges()
Write-Host "  Queue: $($watchEngine.FileQueue.Count) Dateien" -ForegroundColor Gray

# Queue verarbeiten
Write-Host "`n[11] Queue verarbeiten..." -ForegroundColor Yellow
$watchEngine.ProcessQueue()
Write-Host "  Queue nach Verarbeitung: $($watchEngine.FileQueue.Count) Dateien" -ForegroundColor Gray

# Ergebnis prüfen
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "ERGEBNIS:" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$inIncoming = Test-Path "C:\Temp\Incoming\$testFileName"
$nightFiles = Get-ChildItem "C:\Temp\Night" -Recurse -Filter $testFileName -ErrorAction SilentlyContinue
$inQuarantine = Get-ChildItem "C:\Temp\Quarantine" -Recurse -Filter $testFileName -ErrorAction SilentlyContinue

Write-Host "`nTestdatei: $testFileName" -ForegroundColor White
if ($inIncoming) {
    Write-Host "  NOCH in Incoming: JA (PROBLEM!)" -ForegroundColor Red
} else {
    Write-Host "  NOCH in Incoming: NEIN (gut)" -ForegroundColor Green
}

if ($nightFiles) {
    Write-Host "  In Night: JA (ERFOLG!)" -ForegroundColor Green
    Write-Host "    -> $($nightFiles.FullName)" -ForegroundColor Gray
} else {
    Write-Host "  In Night: NEIN" -ForegroundColor Yellow
}

if ($inQuarantine) {
    Write-Host "  In Quarantine: JA (Problem beim Transfer)" -ForegroundColor Yellow
}

Write-Host "`n[Letzte Logs]" -ForegroundColor Gray
Get-Content "logs\watchfolder.log" -Tail 10
'@

# In neuer PowerShell-Instanz ausführen
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command $scriptBlock
