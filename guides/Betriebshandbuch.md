# 📋 Betriebshandbuch - Watch Folder System

## Überblick

Das Watch Folder System ist eine automatisierte Dateiverarbeitungslösung für die Medienarchivierung. Es überwacht konfigurierte Ordner auf neue Dateien und leitet diese basierend auf ihrem Format automatisch an die entsprechenden Zielordner weiter.

### Hauptfunktionen
- **Automatische Dateiüberwachung** mit konfigurierbaren Karenzzeiten
- **Intelligente Formatklassifizierung** (MXF → MAM, PDF → BOX, etc.)
- **Nachtverarbeitung** für unbekannte Dateien
- **Web-Dashboard** für Monitoring und Konfiguration
- **Umfassende Logging** und Fehlerbehandlung
- **Performance-Monitoring** und Alert-System

## Systemarchitektur

### Komponenten
- **WatchFolderService.ps1**: Hauptservice (Windows Service)
- **StatusAPI.ps1**: REST-API für Dashboard und Monitoring
- **NightBatchRunner.ps1**: Nachtverarbeitung (Scheduled Task)
- **Dashboard**: Web-Interface (HTML/JavaScript)
- **Module**: FormatClassifier, RoutingEngine, Logger, etc.

### Datenfluss
```
Watch Folder → Formatklassifizierung → Routing → Zielordner
     ↓
   Logging → Dashboard → Alerts
```

## Installation und Erstkonfiguration

### Voraussetzungen
- Windows Server 2016+ oder Windows 10/11
- PowerShell 5.1+
- .NET Framework 4.7.2+
- Administrator-Rechte

### Installation
```powershell
# Aus dem Projektverzeichnis
.\deploy\Install-WatchFolder.ps1 -InstallPath "C:\WatchFolder"
```

### Erstkonfiguration
1. **Konfiguration anpassen**: `config\config.json`
2. **Watch-Ordner erstellen** und Berechtigungen setzen
3. **Zielordner konfigurieren** (MAM, BOX, Night, Quarantine)
4. **Service starten**: `Start-Service WatchFolder`
5. **Dashboard testen**: `http://localhost:8080`

## Tägliche Betriebsabläufe

### Start des Systems
```powershell
# Service starten
Start-Service WatchFolder

# Status prüfen
Get-Service WatchFolder

# Dashboard öffnen
Start-Process "http://localhost:8080"
```

### Monitoring
- **Dashboard**: Echtzeit-Status, Queue-Größe, Performance-Metriken
- **Logs**: `logs\watchfolder.log` (rotiert automatisch)
- **Queue-Status**: Über API `/api/status` oder Dashboard

### Regelmäßige Checks
- Service-Status alle 4 Stunden prüfen
- Queue-Größe überwachen (< 1000 Dateien)
- Fehler-Rate beobachten (< 5%)
- Speicherplatz auf allen Laufwerken prüfen

## Konfiguration

### Watch Folders
```json
{
  "WatchFolders": [
    {
      "Path": "D:\\Incoming",
      "Enabled": true,
      "GracePeriod": 30,
      "RecursiveWatch": true
    }
  ]
}
```

### Zielordner
```json
{
  "Destinations": {
    "MAM": {
      "Path": "\\\\server\\mam\\incoming",
      "Enabled": true,
      "PreserveFolderStructure": true
    },
    "BOX": {
      "Path": "\\\\server\\box\\incoming",
      "Enabled": true,
      "SanitizeFilenames": true
    }
  }
}
```

### Konfigurationsänderungen
- Über Dashboard: Konfiguration → Änderungen speichern
- Oder direkt in `config\config.json` (Service neu starten erforderlich)

## Wartung

### Wöchentliche Aufgaben
```powershell
# Log-Dateien rotieren (automatisch, aber prüfen)
Get-ChildItem logs\*.log | Sort-Object LastWriteTime -Descending

# Performance-Metriken prüfen
# Über Dashboard: Übersicht → Performance

# Festplattenspeicher prüfen
Get-WmiObject Win32_LogicalDisk | Select-Object Size,FreeSpace
```

### Monatliche Aufgaben
- Konfiguration reviewen und aktualisieren
- Backup der Konfiguration erstellen
- Testläufe mit bekannten Dateiformaten durchführen
- Update-Paket prüfen (falls verfügbar)

### Jährliche Aufgaben
- Vollständige Systemprüfung
- Disaster Recovery Test
- Dokumentation aktualisieren

## Fehlerbehebung

### Häufige Probleme

#### Service startet nicht
```powershell
# Detaillierte Fehlermeldung anzeigen
Get-EventLog -LogName System -Source WatchFolder -Newest 10

# Service manuell starten mit Debug-Ausgabe
.\src\WatchFolderService.ps1 -Debug
```

#### Dateien werden nicht verarbeitet
1. Watch-Ordner Berechtigungen prüfen
2. Karenzzeit abwarten (Standard: 30 Sekunden)
3. Logs auf Fehler prüfen
4. Formatklassifizierung testen: `.\src\QuickTest.ps1`

#### Dashboard nicht erreichbar
```powershell
# Port-Konflikt prüfen
netstat -ano | findstr :8080

# Service neu starten
Restart-Service WatchFolder
```

#### Hohe CPU-/Speicherauslastung
- Performance-Monitoring aktivieren
- Queue-Größe reduzieren (MaxConcurrentTransfers anpassen)
- Memory-Leaks in Logs suchen

### Log-Analyse
```powershell
# Letzte Fehler finden
Select-String -Path logs\watchfolder.log -Pattern "ERROR" -Last 20

# Performance-Probleme identifizieren
Select-String -Path logs\watchfolder.log -Pattern "WARNING.*Performance"
```

## Notfallprozeduren

### Service ausgefallen
1. **Sofortmaßnahmen**:
   ```powershell
   Stop-Service WatchFolder
   .\src\WatchFolderService.ps1 -Debug  # Manueller Testlauf
   ```
2. **Diagnose**:
   - Event-Logs prüfen
   - Systemressourcen überwachen
   - Netzwerkverbindungen testen
3. **Wiederherstellung**:
   ```powershell
   Start-Service WatchFolder
   # Bei anhaltenden Problemen: Reinstall
   .\deploy\Install-WatchFolder.ps1 -Repair
   ```

### Datenverlust
1. **Quarantäne prüfen**: Dateien in `Quarantine`-Ordner suchen
2. **Backup wiederherstellen**: Letzte funktionierende Konfiguration laden
3. **Manuelle Verarbeitung**: `.\src\NightBatchRunner.ps1 -Manual`

### Systemüberlastung
1. **Queue stoppen**: Service temporär anhalten
2. **Last reduzieren**: `MaxConcurrentTransfers` verringern
3. **Ressourcen freigeben**: Unnötige Prozesse beenden

## Backup und Recovery

### Regelmäßige Backups
- **Konfiguration**: Täglich `config\config.json`
- **Logs**: Wöchentlich (rotiert automatisch)
- **System-Image**: Monatlich

### Recovery-Plan
1. **Konfiguration wiederherstellen**:
   ```powershell
   Copy-Item backup\config.json config\config.json
   Restart-Service WatchFolder
   ```

2. **Vollständige Wiederherstellung**:
   ```powershell
   .\deploy\Install-WatchFolder.ps1 -CleanInstall
   # Konfiguration aus Backup wiederherstellen
   ```

## Support und Eskalation

### Level 1: IT-Support (Erstkontakt)
- Service-Status prüfen
- Logs analysieren
- Standard-Fehlerbehebung

### Level 2: Entwicklungsteam
- Komplexe Konfigurationsprobleme
- Performance-Optimierung
- Code-Änderungen

### Level 3: Externe Consultants
- Systemarchitektur-Änderungen
- Neue Feature-Entwicklung
- Kritische Systemprobleme

### Support-Kontakte
- **IT-Support**: support@company.com | +49 123 456789
- **Entwicklung**: dev@company.com | +49 123 456790
- **Externe Beratung**: consultant@vendor.com | +49 123 456791

## Anhänge

### A: Konfigurationsparameter
- `GracePeriod`: Karenzzeit in Sekunden (Standard: 30)
- `MaxConcurrentTransfers`: Maximale parallele Übertragungen (Standard: 5)
- `ProcessingInterval`: Verarbeitungsintervall in Sekunden (Standard: 5)
- `QueueMaxSize`: Maximale Queue-Größe (Standard: 1000)

### B: Dateiformat-Mapping
| Format | Zielordner | Beschreibung |
|--------|------------|--------------|
| .mxf  | MAM       | Media-Dateien |
| .pdf  | BOX       | Dokumente |
| .docx | BOX       | Office-Dokumente |
| *     | Night     | Unbekannte Formate |

### C: Performance-Benchmarks
- **Normale Last**: < 50 Dateien/Stunde
- **Hohe Last**: < 500 Dateien/Stunde
- **CPU-Auslastung**: < 20%
- **RAM-Verbrauch**: < 500MB

---

**Dokument-Version:** 1.0  
**Letzte Aktualisierung:** 23.09.2025  
**Verantwortlich:** IT-Operations Team</content>
<parameter name="filePath">c:\GitHub\Archive_Watchfolder\guides\Betriebshandbuch.md