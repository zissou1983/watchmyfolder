# 🔧 Troubleshooting-Guide - Watch Folder System

## Übersicht

Dieser Guide hilft bei der Diagnose und Behebung häufiger Probleme im Watch Folder System. Für jedes Problem werden Ursachen, Diagnoseschritte und Lösungen beschrieben.

## Häufige Probleme und Lösungen

### 1. Service startet nicht

**Symptome:**
- Windows Service "WatchFolder" bleibt im Status "Starting"
- Fehler beim manuellen Start über PowerShell
- Dashboard nicht erreichbar

**Mögliche Ursachen:**
- Konfigurationsfehler in `config.json`
- Fehlende Berechtigungen für Service-Account
- Port-Konflikte (Standard: 8080)
- Beschädigte Modul-Dateien

**Diagnose:**
```powershell
# Service-Status prüfen
Get-Service WatchFolder

# Detaillierte Fehlermeldung
Get-EventLog -LogName System -Source WatchFolder -Newest 5

# Konfiguration validieren
.\src\ConfigManager.ps1 -Validate

# Manuelle Ausführung testen
.\src\WatchFolderService.ps1 -Debug
```

**Lösungen:**

**Konfigurationsfehler:**
```powershell
# Backup erstellen
Copy-Item config\config.json config\config.json.backup

# Konfiguration zurücksetzen
.\src\ConfigManager.ps1 -Reset
```

**Berechtigungsprobleme:**
```powershell
# Service-Account Berechtigungen prüfen
$serviceAccount = (Get-WmiObject Win32_Service -Filter "Name='WatchFolder'").StartName
Write-Host "Service Account: $serviceAccount"

# Berechtigungen für Watch-Ordner setzen
icacls "C:\WatchFolder" /grant "$serviceAccount:(OI)(CI)F" /T
```

**Port-Konflikte:**
```powershell
# Belegte Ports prüfen
netstat -ano | findstr :8080

# Alternativen Port konfigurieren
# In config.json: "WebPort": 8081
```

### 2. Dateien werden nicht verarbeitet

**Symptome:**
- Dateien bleiben im Watch-Ordner
- Keine Log-Einträge für neue Dateien
- Queue-Größe bleibt bei 0

**Mögliche Ursachen:**
- FileSystemWatcher nicht aktiv
- Karenzzeit zu lang eingestellt
- Dateien werden noch geschrieben
- Berechtigungsprobleme

**Diagnose:**
```powershell
# Queue-Status prüfen
# Über Dashboard: http://localhost:8080
# Oder API: Invoke-RestMethod http://localhost:8080/api/status

# Watch-Ordner Berechtigungen
icacls "D:\Incoming" /T

# Karenzzeit prüfen (Standard: 30 Sekunden)
Get-Content config\config.json | ConvertFrom-Json | Select-Object -ExpandProperty WatchFolders
```

**Lösungen:**

**Karenzzeit anpassen:**
```json
{
  "WatchFolders": [
    {
      "Path": "D:\\Incoming",
      "GracePeriod": 10
    }
  ]
}
```

**FileSystemWatcher neu starten:**
```powershell
Restart-Service WatchFolder
```

**Testdatei erstellen:**
```powershell
# Testdatei erstellen und beobachten
New-Item -Path "D:\Incoming\test.txt" -ItemType File -Value "Test content"
Start-Sleep 35  # Karenzzeit abwarten
Get-ChildItem "D:\Incoming"  # Sollte leer sein
```

### 3. Falsche Datei-Routing

**Symptome:**
- MXF-Dateien landen in BOX-Ordner
- PDF-Dateien werden zu MAM geleitet
- Unbekannte Dateien bleiben im Night-Ordner

**Mögliche Ursachen:**
- FormatClassifier-Fehler
- Falsche Datei-Erweiterungen
- Korrupte Dateien
- Konfigurationsfehler

**Diagnose:**
```powershell
# Format-Klassifizierung testen
.\src\QuickTest.ps1 -FilePath "C:\TestDatei.mxf"

# Logs nach Routing-Fehlern durchsuchen
Select-String -Path logs\watchfolder.log -Pattern "ERROR.*Routing"

# Datei-Header prüfen
.\src\FormatClassifier.ps1 -Analyze "C:\TestDatei.unknown"
```

**Lösungen:**

**Format-Datenbank aktualisieren:**
```powershell
# In FormatClassifier.ps1 neue Formate hinzufügen
$FormatDatabase = @{
    "MAM" = @(".mxf", ".mov", ".mp4")
    "BOX" = @(".pdf", ".docx", ".jpg")
}
```

**Manuelle Reklassifizierung:**
```powershell
# Datei manuell routen
.\src\RoutingEngine.ps1 -FilePath "C:\ProblemDatei.pdf" -Destination "BOX"
```

### 4. Performance-Probleme

**Symptome:**
- Hohe CPU-Auslastung
- Langsame Dateiverarbeitung
- Große Queue-Größen
- System reagiert träge

**Mögliche Ursachen:**
- Zu viele gleichzeitige Transfers
- Große Dateien blockieren Queue
- Unzureichende Systemressourcen
- Netzwerkengpässe

**Diagnose:**
```powershell
# Performance-Metriken
Invoke-RestMethod http://localhost:8080/api/performance

# Systemressourcen
Get-Counter '\Processor(_Total)\% Processor Time'
Get-Counter '\Memory\Available MBytes'

# Queue-Status
Invoke-RestMethod http://localhost:8080/api/status

# Aktive Operationen prüfen
Invoke-RestMethod http://localhost:8080/api/active-operations
```

**Lösungen:**

**Parallelität reduzieren:**
```json
{
  "Performance": {
    "MaxConcurrentTransfers": 3
  }
}
```

**Queue-Limits anpassen:**
```json
{
  "Performance": {
    "QueueMaxSize": 500
  }
}
```

**Blockierende Operationen abbrechen:**
```powershell
# Aktive Operationen anzeigen
$operations = Invoke-RestMethod http://localhost:8080/api/active-operations

# Operation abbrechen
Invoke-WebRequest "http://localhost:8080/api/cancel-operation?id=$($operations.operations[0].Id)" -Method POST
```

### 4.1 Operations-Übersicht verwenden

**Neue Funktionalität:** Seit Version 1.0 bietet das System eine umfassende Operations-Übersicht zur Überwachung aktiver Dateiverarbeitungen.

**Dashboard-Zugriff:**
- Öffnen Sie das Dashboard: `http://localhost:8080`
- Navigieren Sie zum Abschnitt "Aktive Operationen"
- Die Liste aktualisiert sich automatisch alle 5 Sekunden

**Verfügbare Informationen:**
- **Dateiname:** Name der verarbeiteten Datei
- **Status:** Aktueller Verarbeitungsstatus (Analysieren, Verarbeiten, Abgeschlossen)
- **Fortschritt:** Visuelle Fortschrittsanzeige
- **Dauer:** Verarbeitungszeit seit Start
- **Aktionen:** Abbrechen-Button für laufende Operationen

**Status-Farbcodes:**
- 🔵 Blau: Analysieren (Datei wird untersucht)
- 🟡 Gelb: Verarbeiten (Datei wird transferiert)
- 🟢 Grün: Abgeschlossen (erfolgreich)
- 🔴 Rot: Fehler (fehlgeschlagen)

**Operation abbrechen:**
```powershell
# Über Dashboard: Klick auf "Abbrechen" Button
# Oder per API:
Invoke-WebRequest "http://localhost:8080/api/cancel-operation?id=<OperationId>" -Method POST
```

**API-Endpunkte für Operationen:**
```powershell
# Aktive Operationen auflisten
Invoke-RestMethod http://localhost:8080/api/active-operations

# Einzelne Operation abbrechen
Invoke-WebRequest "http://localhost:8080/api/cancel-operation?id=<OperationId>" -Method POST
```

**Troubleshooting mit Operations-Übersicht:**
- **Hängende Operationen:** Verwenden Sie die Abbrechen-Funktion
- **Performance-Probleme:** Überwachen Sie die Verarbeitungsdauer
- **Queue-Blockaden:** Identifizieren Sie langlaufende Operationen
- **Systemlast:** Beobachten Sie gleichzeitige Operationen

### 5. Dashboard nicht erreichbar

**Symptome:**
- HTTP 404 oder Connection refused
- Dashboard lädt nicht
- API-Aufrufe schlagen fehl

**Mögliche Ursachen:**
- StatusAPI nicht gestartet
- Port-Konflikte
- Firewall-Blockierung
- Service nicht aktiv

**Diagnose:**
```powershell
# Service-Status
Get-Service WatchFolder

# Port-Status
netstat -ano | findstr :8080

# Firewall-Regeln
Get-NetFirewallRule | Where-Object DisplayName -like "*WatchFolder*"

# API-Test
try {
    Invoke-WebRequest http://localhost:8080/api/status
} catch {
    Write-Host "API nicht erreichbar: $($_.Exception.Message)"
}
```

**Lösungen:**

**Firewall konfigurieren:**
```powershell
# Firewall-Regel erstellen
New-NetFirewallRule -DisplayName "WatchFolder Dashboard" -Direction Inbound -Protocol TCP -LocalPort 8080 -Action Allow
```

**Service neu starten:**
```powershell
Restart-Service WatchFolder
```

### 6. Nachtverarbeitung funktioniert nicht

**Symptome:**
- Dateien bleiben über Nacht im Night-Ordner
- Scheduled Task läuft nicht
- Keine Verarbeitung außerhalb Bürozeiten

**Mögliche Ursachen:**
- Task Scheduler Konfiguration
- Zeitfenster-Fehler
- Berechtigungsprobleme
- NightBatchRunner.ps1 Fehler

**Diagnose:**
```powershell
# Scheduled Tasks prüfen
Get-ScheduledTask -TaskName "*Night*" | Get-ScheduledTaskInfo

# Task-Historie
Get-ScheduledTask -TaskName "WatchFolderNightBatch" | Get-ScheduledTaskInfo | Select-Object -ExpandProperty LastTaskResult

# Manuelle Ausführung testen
.\src\NightBatchRunner.ps1 -ConfigPath config\config.json
```

**Lösungen:**

**Task Scheduler reparieren:**
```powershell
# Task neu registrieren
.\deploy\Install-WatchFolder.ps1 -RepairScheduledTask
```

**Zeitfenster prüfen:**
```json
{
  "Destinations": {
    "Night": {
      "ProcessingWindow": {
        "Start": "20:00",
        "End": "06:00"
      }
    }
  }
}
```

### 7. Log-Dateien wachsen zu schnell

**Symptome:**
- Log-Dateien > 100MB
- Festplattenspeicher knapp
- Performance-Einbußen durch Logging

**Mögliche Ursachen:**
- Debug-Level zu hoch
- Zu viele Log-Einträge
- Rotation nicht aktiv

**Diagnose:**
```powershell
# Log-Dateien analysieren
Get-ChildItem logs\*.log | Sort-Object Length -Descending

# Log-Level prüfen
Get-Content config\config.json | ConvertFrom-Json | Select-Object -ExpandProperty Logging
```

**Lösungen:**

**Log-Level anpassen:**
```json
{
  "Logging": {
    "Level": "Info"
  }
}
```

**Manuelle Rotation:**
```powershell
# Alte Logs archivieren
Get-ChildItem logs\*.log | Where-Object LastWriteTime -lt (Get-Date).AddDays(-7) | Move-Item -Destination logs\archive\
```

## Erweiterte Diagnose-Tools

### System Health Check
```powershell
# Vollständige Systemdiagnose
.\src\SystemHealthCheck.ps1
```

### Performance-Profiling
```powershell
# Performance-Analyse
.\tests\performance\Test-PerformanceProfiling.ps1
```

### Log-Analyzer
```powershell
# Automatische Log-Analyse
.\src\LogAnalyzer.ps1 -Path logs\watchfolder.log -LastHours 24
```

## Eskalationsmatrix

| Problem-Schwere | Reaktionszeit | Eskalation |
|----------------|---------------|------------|
| Kritisch (System down) | Sofort | Level 3 |
| Hoch (Funktion eingeschränkt) | < 4h | Level 2 |
| Mittel (Einzelfehler) | < 24h | Level 1 |
| Niedrig (Kosmetisch) | Nächster Arbeitstag | Level 1 |

## Support-Kontakte

- **Level 1:** IT-Support (täglich 8:00-18:00)
- **Level 2:** Systemadministrator (Bereitschaft)
- **Level 3:** Entwicklungsteam (nach Vereinbarung)

---

**Dokument-Version:** 1.1  
**Letzte Aktualisierung:** 23.09.2025  
**Verantwortlich:** IT-Operations Team</content>
<parameter name="filePath">c:\GitHub\Archive_Watchfolder\guides\Troubleshooting-Guide.md
