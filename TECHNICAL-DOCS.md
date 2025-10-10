# 🔧 Watch Folder - Technische Dokumentation

## 📁 Datei-Übersicht (Finale Version)

### ✅ Funktionsfähige Dateien:

| Datei | Typ | Beschreibung | Status |
|-------|-----|--------------|--------|
| `WatchFolder.bat` | Batch | **Haupt-Launcher** - Einfach und zuverlässig | ✅ Production Ready |

### 📋 Support-Dateien:

| Datei | Zweck |
|-------|-------|
| `src/WatchFolderService.ps1` | Backend-Service PowerShell |
| `config/config.json` | Hauptkonfiguration |
| `QUICK-START.md` | Benutzer-Anleitung |
| `README.md` | Projekt-Dokumentation |

### 🗑️ Archivierte Dateien:

- **`backup/`** - 50+ experimentelle Versionen
- Alle EXE-Builds und Installer
- ps2exe-Experimente
- Komplexe Launcher-Varianten
- Registry-Fixes und Build-Tools

## 🏗️ Architektur

### Komponenten:
```
WatchFolder.bat
├── Backend-Service (PowerShell)
│   ├── FileSystemWatcher
│   ├── Format-Klassifizierung  
│   └── Datei-Routing
├── Frontend-Dashboard
│   ├── Electron-App (preferred)
│   └── Web-Dashboard (fallback)
└── Status-API (REST)
```

### Startup-Prozess:
1. **Batch startet** → PowerShell-Service aktiviert
2. **Backend-Service** → WatchFolderService.ps1 versteckt gestartet
3. **Node.js-Check** → Electron oder Web-Dashboard
4. **Dashboard öffnet** → Natives Fenster oder Browser
5. **API läuft** → Port 8082 für Kommunikation

## 🔄 Datei-Verarbeitung

### Workflow:
```
Datei erkannt → Karenzzeit → Format-Analyse → Routing → Transfer → Logging
```

### Format-Erkennung:
- **Magic Numbers** - Binäre Signatur-Analyse
- **File Extensions** - Endungs-basierte Klassifizierung  
- **MIME-Type Detection** - Content-Type-Bestimmung

### Ziel-Routing:
- **MAM**: Video/Audio-Dateien (`.mxf`, `.mp4`, `.wav`, etc.)
- **BOX**: Dokumente (`.pdf`, `.docx`, `.xlsx`, etc.)
- **Custom**: Benutzerdefinierte Ordner mit eigenen Formaten
- **Quarantine**: Unbekannte oder fehlerhafte Dateien

## 🛠️ Konfiguration

### config.json Struktur:
```json
{
  "watchFolders": [
    {
      "Path": "C:\\Temp\\Incoming",
      "GracePeriod": 30
    }
  ],
  "destinations": {
    "MAM": { "Path": "C:\\Temp\\MAM" },
    "BOX": { "Path": "C:\\Temp\\BOX" },
    "CUSTOM": { "Path": "C:\\Temp\\Custom" }
  },
  "Formats": {
    "MAM": [".mxf", ".mp4", ".mov"],
    "BOX": [".pdf", ".docx", ".xlsx"],
    "CUSTOM": [".zip", ".rar"]
  }
}
```

### Dashboard-Features:
- **Live-Konfiguration** - Änderungen ohne Neustart
- **Format-Editor** - Drag & Drop Format-Zuweisung
- **Custom Destinations** - Eigene Zielordner erstellen
- **Night Batch** - Zeitfenster-Konfiguration

## 🚦 API-Endpunkte

### Status-API (Port 8082):
- `GET /api/status` - Service-Status
- `GET /api/config` - Aktuelle Konfiguration
- `POST /api/config` - Konfiguration speichern
- `GET /api/activities` - Letzte Aktivitäten
- `POST /api/night-batch/start` - Nachtverarbeitung starten

### Dashboard-API (Port 8080):
- Gleiche Endpunkte über SimpleWebServer
- Zusätzlich: Static File Serving für Dashboard

## 🔧 Entwicklung & Wartung

### Starten:
```cmd
WatchFolder.bat
```

### Debugging:
```powershell
# Direkte Ausführung für Debugging:
.\src\WatchFolderService.ps1 -ConfigPath .\config\config.json -Debug
```

### Log-Dateien:
- `logs\watchfolder-YYYY-MM-DD.log` - Service-Logs
- `logs\errors-YYYY-MM-DD.log` - Fehler-Logs
- `logs\performance-YYYY-MM-DD.log` - Performance-Metriken

## 📈 Performance

### Optimierungen:
- **Asynchrone Verarbeitung** - Non-blocking File Operations
- **Batch-Transfers** - Mehrere Dateien gleichzeitig
- **Memory Management** - Automatische Garbage Collection
- **Log Rotation** - Automatische Archivierung

### Monitoring:
- **FileSystemWatcher** - Echtzeit-Überwachung
- **Performance Counters** - CPU/Memory-Tracking
- **Operation Tracking** - Durchsatz-Messung
- **Error Tracking** - Fehlerrate-Überwachung

---

**Status**: Production Ready  
**Version**: 6.0 (Vereinfacht - Nur Batch)  
**Letzte Aktualisierung**: Oktober 2025