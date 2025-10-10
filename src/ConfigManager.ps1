# Konfigurations-Manager für Watch Folder Service
param(
    [string]$ConfigPath = ".\config\config.json",
    [switch]$Edit,
    [switch]$Validate,
    [switch]$ConfigureDestinations
)

function Show-Config {
    param($Config)
    
    Write-Host "`n=== Watch Folder Konfiguration ===" -ForegroundColor Cyan
    
    Write-Host "`nÜberwachte Ordner:" -ForegroundColor Yellow
    foreach ($folder in $Config.WatchFolders) {
        $status = if ($folder.Enabled) { "[+]" } else { "[-]" }
        Write-Host "  $status $($folder.Path) (Karenzzeit: $($folder.GracePeriod)s)" -ForegroundColor White
    }
    
    Write-Host "`nZielordner:" -ForegroundColor Yellow
    foreach ($dest in $Config.Destinations.PSObject.Properties) {
        $status = if ($dest.Value.Enabled) { "[+]" } else { "[-]" }
        Write-Host "  $status $($dest.Name) -> $($dest.Value.Path)" -ForegroundColor White
    }
    
    Write-Host "`nLogging:" -ForegroundColor Yellow
    Write-Host "  Level: $($Config.Logging.Level)" -ForegroundColor White
    Write-Host "  Pfad: $($Config.Logging.Path)" -ForegroundColor White
    
    Write-Host "`nMonitoring:" -ForegroundColor Yellow
    Write-Host "  Dashboard: $(if ($Config.Monitoring.EnableDashboard) { 'Aktiviert' } else { 'Deaktiviert' })" -ForegroundColor White
    Write-Host "  Port: $($Config.Monitoring.WebPort)" -ForegroundColor White
}

function Configure-Destinations {
    param([string]$ConfigPath)
    
    Write-Host "`n=== Zielordner konfigurieren ===" -ForegroundColor Cyan
    
    try {
        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
        
        Write-Host "`nAktuelle Zielordner:" -ForegroundColor Yellow
        foreach ($dest in $config.Destinations.PSObject.Properties) {
            Write-Host "  $($dest.Name): $($dest.Value.Path)" -ForegroundColor White
        }
        
        Write-Host "`nGeben Sie neue Pfade ein (leer lassen fuer keine Aenderung):" -ForegroundColor Green
        
        # MAM konfigurieren
        $newMAMPath = Read-Host "MAM Zielordner [$($config.Destinations.MAM.Path)]"
        if ($newMAMPath -and $newMAMPath.Trim()) {
            $config.Destinations.MAM.Path = $newMAMPath.Trim()
            Write-Host "MAM Pfad aktualisiert: $($config.Destinations.MAM.Path)" -ForegroundColor Green
        }
        
        # BOX konfigurieren
        $newBOXPath = Read-Host "BOX Zielordner [$($config.Destinations.BOX.Path)]"
        if ($newBOXPath -and $newBOXPath.Trim()) {
            $config.Destinations.BOX.Path = $newBOXPath.Trim()
            Write-Host "BOX Pfad aktualisiert: $($config.Destinations.BOX.Path)" -ForegroundColor Green
        }
        
        # Night konfigurieren
        $newNightPath = Read-Host "Night Zielordner [$($config.Destinations.Night.Path)]"
        if ($newNightPath -and $newNightPath.Trim()) {
            $config.Destinations.Night.Path = $newNightPath.Trim()
            Write-Host "Night Pfad aktualisiert: $($config.Destinations.Night.Path)" -ForegroundColor Green
        }
        
        # Konfiguration speichern
        $config | ConvertTo-Json -Depth 10 | Set-Content -Path $ConfigPath -Encoding UTF8
        Write-Host "`nKonfiguration gespeichert!" -ForegroundColor Green
        
    } catch {
        Write-Host "Fehler beim Konfigurieren der Zielordner: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Test-Config {
    param([string]$ConfigPath)
    
    Write-Host "Validiere Konfiguration..." -ForegroundColor Yellow
    
    try {
        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
        $errors = @()
        
        # Watch-Ordner prüfen
        foreach ($folder in $config.WatchFolders) {
            if ($folder.Enabled -and -not (Test-Path $folder.Path)) {
                $errors += "Watch-Ordner existiert nicht: $($folder.Path)"
            }
        }
        
        if ($errors.Count -eq 0) {
            Write-Host "[OK] Konfiguration ist gültig" -ForegroundColor Green
        } else {
            Write-Host "[FEHLER] Konfigurationsfehler gefunden:" -ForegroundColor Red
            $errors | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
        }
        
    } catch {
        Write-Host "[FEHLER] Konfigurationsdatei ist ungültig: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Hauptprogramm
try {
    if (-not (Test-Path $ConfigPath)) {
        Write-Host "Konfigurationsdatei nicht gefunden: $ConfigPath" -ForegroundColor Red
        exit 1
    }
    
    $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    
    if ($Validate) {
        Test-Config -ConfigPath $ConfigPath
    } elseif ($Edit) {
        Write-Host "Konfiguration bearbeiten mit:" -ForegroundColor Green
        Write-Host "  notepad $ConfigPath" -ForegroundColor White
        Write-Host "oder" -ForegroundColor Yellow
        Write-Host "  code $ConfigPath" -ForegroundColor White
    } elseif ($ConfigureDestinations) {
        Configure-Destinations -ConfigPath $ConfigPath
    } else {
        Show-Config -Config $config
    }
    
} catch {
    Write-Host "Fehler: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}