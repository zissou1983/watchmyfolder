# Watch Folder Service

Ein automatisiertes System zur Überwachung, Klassifizierung und Weiterleitung von Dateien basierend auf ihrer Art und Herkunft.

## 🎯 Überblick

Das Watch Folder System überwacht konfigurierte Ordner und leitet Dateien automatisch an die entsprechenden Zielsysteme weiter:

- **MAM-Dateien** (MXF, Video, Audio) → MAM-System
- **BOX-Dateien** (Dokumente) → BOX-System  
- **Benutzerdefinierte Zielordner** → Eigene Format-Konfigurationen
- **Unbekannte Dateien** → Night-Ordner für manuelle Verarbeitung

## 🚀 Schnellstart

```cmd
# Einfach ausführen:
WatchFolder.bat
```
- **System-Dateien** → Werden ignoriert

## 🚀 Features

- ✅ **Native EXE-Anwendung** - Ein-Klick-Start ohne Abhängigkeiten
- ✅ **Electron-Dashboard** - Natives Windows-Fenster mit moderner UI
- ✅ **Echtzeit-Überwachung** mit FileSystemWatcher
- ✅ **Intelligente Klassifizierung** via Magic Numbers und Extensions
- ✅ **Benutzerdefinierte Zielordner** mit eigenen Format-Konfigurationen
- ✅ **Karenzzeit-Management** für sichere Dateiübertragung
- ✅ **Atomare Transfers** mit Checksummen-Validierung
- ✅ **Sonderzeichen-Bereinigung** für BOX-Kompatibilität
- ✅ **Umfassendes Logging** mit automatischer Rotation
- ✅ **Nachtverarbeitung** für Batch-Jobs
- ✅ **Professioneller Installer** mit Desktop-Verknüpfung

## ⚠️ Wichtige Hinweise

## 📋 **Verwendung:**

- **Einfach:** `WatchFolder.bat` direkt ausführen - keine Installation nötig!

### **Systemanforderungen:**
- Windows 10/11
- Node.js (wird automatisch erkannt, Web-Dashboard als Fallback)
- .NET Framework 4.7.2+ (für EXE)

### **Ordner-Struktur:**
- **Funktionsfähig:** Aktuelles Verzeichnis mit `WatchFolder.bat`  
- **Archiv:** `trash/` enthält 27+ alte, nicht-funktionierende Versionen
- **Deployment:** Für Produktion die `deploy/`-Skripte verwenden

## 🛠️ Installation & Start

### Option 1: Portable Verwendung (Empfohlen)

```cmd
# Direkt aus dem Projektverzeichnis:
WatchFolder.exe
```

✅ **Vorteile:**
- Kein Installation nötig
- Alle Dateien bleiben im Projektverzeichnis  
- Sofortiger Start
- Einfaches Update (neue EXE-Datei ersetzen)

### Option 2: Vollständige Installation

```cmd
# Als Administrator ausführen:
Install.bat
```

✅ **Features:**
- Installation nach `C:\Program Files\WatchFolder`
- Desktop-Verknüpfung wird erstellt
- Startmenü-Eintrag (optional)
- Professionelle Deinstallation möglich

### Option 3: Backup-Start

```cmd
# Falls EXE-Probleme:
WatchFolder.bat
```

### Was passiert beim Start:

1. **Backend-Service** startet versteckt im Hintergrund
2. **Node.js-Prüfung** - Electron oder Web-Dashboard
3. **Dashboard öffnet sich** - Natives Fenster oder Browser
4. **Überwachung aktiv** - Sofortige Datei-Verarbeitung

### Manuelle Installation

1. **Verzeichnisstruktur erstellen:**
```powershell
mkdir C:\WatchFolder\{src,config,logs,data}
```

2. **Dateien kopieren:**
```powershell
Copy-Item .\src\* C:\WatchFolder\src\ -Recurse
Copy-Item .\config\* C:\WatchFolder\config\ -Recurse
```

3. **Konfiguration anpassen:**
```powershell
notepad C:\WatchFolder\config\config.json
```

4. **Service manuell starten:**
```powershell
cd C:\WatchFolder
.\src\WatchFolderService.ps1 -ConfigPath .\config\config.json
```

## ⚙️ Konfiguration

### Basis-Konfiguration (`config/config.json`)

```json
{
    "WatchFolders": [
        {
            "Path": "D:\\Incoming",
            "Enabled": true,
            "GracePeriod": 30,
            "RecursiveWatch": true
        }
    ],
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

### Umgebungsspezifische Konfiguration

- **Development:** Debug-Logging, lokale Pfade
- **Staging:** Info-Logging, Test-Server
- **Production:** Info-Logging, Produktions-Server

## 🎮 Verwendung

### Service-Steuerung

```powershell
# Service starten
Start-Service WatchFolder

# Service stoppen  
Stop-Service WatchFolder

# Status prüfen
Get-Service WatchFolder
```

### Dashboard

Das Web-Dashboard ist verfügbar unter: `http://localhost:8080`

Features:
- Real-time Service-Status
- Verarbeitungsstatistiken
- Überwachte Ordner
- Letzte Aktivitäten
- Performance-Charts
- Fehler-Log

### Manuelle Ausführung

```powershell
# Mit Debug-Ausgabe
.\src\WatchFolderService.ps1 -ConfigPath .\config\config.json -Debug

# Nur Konfiguration testen
.\src\WatchFolderService.ps1 -ConfigPath .\config\config.json -TestConfig
```

## 📊 Monitoring

### Log-Dateien

- **Haupt-Log:** `logs/watchfolder.log`
- **Service-Log:** `logs/service-stdout.log`
- **Fehler-Log:** `logs/service-stderr.log`

### Performance-Metriken

- Verarbeitungsrate: >100 Dateien/Minute
- Fehlerrate: <1%
- Verfügbarkeit: 99.9%
- Queue-Größe: <1000 Dateien

### Alerts

Das System sendet Benachrichtigungen bei:
- Queue-Überlauf (>1000 Dateien)
- Hohe Fehlerrate (>5 Fehler/10min)
- Service-Ausfall
- Festplatte voll

## 🧪 Testing

### Unit Tests ausführen

```powershell
# Alle Tests
Invoke-Pester .\tests\

# Spezifische Tests
Invoke-Pester .\tests\unit\Test-Logger.ps1
Invoke-Pester .\tests\unit\Test-FormatClassifier.ps1
```

### Integrationstests

```powershell
# Vollständiger Workflow-Test
.\tests\integration\Test-WatchFolder.ps1

# Performance-Tests
.\tests\performance\Test-LargeFiles.ps1
```

### Test-Coverage

Ziel: >80% Code-Coverage für alle Module

## 🔧 Entwicklung

### Entwicklungsumgebung

```powershell
# Entwicklungsinstallation
.\deploy\Install-WatchFolder.ps1 -Environment Development -InstallPath "C:\Dev\WatchFolder"

# VSCode Extensions installieren
code --install-extension ms-vscode.powershell
```

### Code-Struktur

```
src/
├── WatchFolderService.ps1      # Hauptservice
├── modules/
│   ├── Logger.ps1              # Logging-System
│   ├── FormatClassifier.ps1    # Dateiklassifizierung
│   ├── WatchEngine.ps1         # Ordnerüberwachung
│   └── RoutingEngine.ps1       # Datei-Routing
├── dashboard/                  # Web-Dashboard
└── api/                       # REST API
```

### Beitragen

1. Fork des Repositories
2. Feature-Branch erstellen: `git checkout -b feature/neue-funktion`
3. Tests schreiben und ausführen
4. Commit mit aussagekräftiger Nachricht
5. Pull Request erstellen

## 🚨 Troubleshooting

### Häufige Probleme

**Service startet nicht:**
```powershell
# Logs prüfen
Get-Content C:\WatchFolder\logs\service-stderr.log -Tail 50

# Berechtigungen prüfen
Test-Path C:\WatchFolder -PathType Container
```

**Dateien werden nicht verarbeitet:**
```powershell
# Queue-Status prüfen
Invoke-RestMethod http://localhost:8080/api/status

# Watch-Ordner prüfen
Test-Path "D:\Incoming" -PathType Container
```

**Dashboard nicht erreichbar:**
```powershell
# Port prüfen
netstat -an | findstr :8080

# Firewall prüfen
New-NetFirewallRule -DisplayName "WatchFolder" -Direction Inbound -Port 8080 -Protocol TCP -Action Allow
```

### Support-Kontakte

- **Level 1:** IT-Support Team
- **Level 2:** Entwicklungsteam  
- **Level 3:** Externe Consultants

## 📝 Changelog

### Version 1.0.0 (2024-11-XX)
- ✅ Initiale Implementierung
- ✅ Alle Kern-Features
- ✅ Web-Dashboard
- ✅ Windows Service Integration
- ✅ Umfassende Tests

## 📄 Lizenz

Dieses Projekt ist unter der MIT-Lizenz lizenziert. Siehe [LICENSE](LICENSE) für Details.

## 🙏 Danksagungen

- PowerShell Community für Best Practices
- Chart.js für Dashboard-Visualisierung
- Pester Framework für Testing

---

**Dokumentation Version:** 1.0.0  
**Letzte Aktualisierung:** September 2025  
**Autor:** Malte Metzner