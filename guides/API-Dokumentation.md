# 🔌 API-Dokumentation - Watch Folder System

## Übersicht

Das Watch Folder System stellt eine REST-API zur Verfügung, die Monitoring, Konfiguration und Steuerung ermöglicht. Die API läuft standardmäßig auf Port 8080.

**Base URL:** `http://localhost:8080`

## Authentifizierung

Die API verwendet derzeit keine Authentifizierung. In Produktionsumgebungen sollte eine Authentifizierung implementiert werden.

## Allgemeine Response-Formate

### Erfolgreiche Responses
```json
{
  "success": true,
  "data": { ... },
  "timestamp": "2025-09-23T10:30:00Z"
}
```

### Fehler-Responses
```json
{
  "success": false,
  "error": "Beschreibung des Fehlers",
  "code": "ERROR_CODE",
  "timestamp": "2025-09-23T10:30:00Z"
}
```

## API-Endpunkte

### 1. System-Status

**GET** `/api/status`

Gibt den aktuellen Status des Watch Folder Systems zurück.

**Response:**
```json
{
  "isRunning": true,
  "queueSize": 5,
  "uptime": 3600,
  "watchFolders": [
    {
      "path": "C:\\Temp\\Incoming",
      "active": true
    }
  ]
}
```

**HTTP Status Codes:**
- `200` - Erfolgreich
- `500` - Server-Fehler

### 2. Statistiken

**GET** `/api/stats`

Gibt Verarbeitungsstatistiken der letzten Zeit zurück.

**Response:**
```json
{
  "mamCount": 25,
  "boxCount": 15,
  "nightCount": 3,
  "errorCount": 1,
  "hourlyData": [
    {
      "hour": 9,
      "count": 5
    },
    {
      "hour": 10,
      "count": 8
    }
  ]
}
```

### 3. Aktivitäten

**GET** `/api/activities`

Gibt die letzten Aktivitäten des Systems zurück.

**Query Parameter:**
- `limit` (optional): Maximale Anzahl der zurückzugebenden Aktivitäten (Standard: 10)

**Response:**
```json
[
  {
    "title": "MXF-Datei verarbeitet",
    "description": "video001.mxf → MAM",
    "timestamp": "2025-09-23T09:45:00Z"
  },
  {
    "title": "PDF-Dokument verarbeitet",
    "description": "document.pdf → BOX",
    "timestamp": "2025-09-23T09:40:00Z"
  }
]
```

### 4. Fehler-Liste

**GET** `/api/errors`

Gibt die letzten Fehler des Systems zurück.

**Query Parameter:**
- `limit` (optional): Maximale Anzahl der zurückzugebenden Fehler (Standard: 10)

**Response:**
```json
[
  {
    "message": "Datei konnte nicht verschoben werden",
    "file": "C:\\Temp\\Incoming\\error.mxf",
    "timestamp": "2025-09-23T09:30:00Z",
    "code": "MOVE_FAILED"
  }
]
```

### 5. Konfiguration

**GET** `/api/config`

Gibt die aktuelle Systemkonfiguration zurück.

**Response:**
```json
{
  "WatchFolders": [...],
  "Destinations": {...},
  "Logging": {...},
  "Performance": {...}
}
```

**POST** `/api/config`

Aktualisiert die Systemkonfiguration.

**Request Body:**
```json
{
  "WatchFolders": [...],
  "Logging": {
    "Level": "Debug"
  }
}
```

**Response:**
```json
{
  "success": true,
  "message": "Konfiguration gespeichert"
}
```

### 6. Nachtverarbeitung Status

**GET** `/api/night-batch/status`

Gibt den Status der Nachtverarbeitung zurück.

**Response:**
```json
{
  "isEnabled": true,
  "processingWindow": {
    "start": "20:00",
    "end": "06:00",
    "isActive": false
  },
  "nightFolder": {
    "path": "C:\\Temp\\Night",
    "exists": true,
    "fileCount": 15
  },
  "lastRun": {
    "timestamp": "2025-09-22T20:00:00Z",
    "filesProcessed": 150,
    "duration": "2h 30m",
    "status": "success"
  },
  "canStartManually": true
}
```

**POST** `/api/night-batch/start`

Startet die Nachtverarbeitung manuell.

**Response:**
```json
{
  "success": true,
  "message": "Nachtverarbeitung wurde gestartet",
  "jobId": "abc123"
}
```

### 7. Performance-Metriken

**GET** `/api/performance`

Gibt aktuelle Performance-Metriken zurück.

**Response:**
```json
{
  "CpuUsagePercent": 15.5,
  "MemoryAvailableMB": 4096,
  "ProcessingRatePerMinute": 25,
  "ErrorRatePercent": 0.5,
  "Uptime": {
    "Formatted": "2h 30m",
    "TotalSeconds": 9000
  },
  "QueueSize": 3,
  "FilesProcessed": 1250
}
```

### 8. Ordner-Browser

**GET** `/api/browse-folder`

Öffnet einen nativen Ordner-Browser-Dialog auf dem Server und gibt den ausgewählten Pfad zurück.

**Query Parameter:**
- `type` (optional): Typ des Ordners (`general`, `watch`, `destination`, `log`, `backup`) - Default: `general`
- `currentPath` (optional): Aktueller Pfad als Vorschlag - Default: `""`
- `description` (optional): Beschreibung für den Dialog - Default: `""`
- `destinationType` (optional): Spezifischer Zieltyp für destination-Typ - Default: `""`

**Beispiele:**
```
GET /api/browse-folder?type=watch&currentPath=C:\Temp
GET /api/browse-folder?type=destination&destinationType=MAM&currentPath=\\server\mam
```

**Response bei Erfolg:**
```json
{
  "success": true,
  "path": "C:\\Selected\\Folder\\Path"
}
```

**Response bei Abbruch/Fehler:**
```json
{
  "success": false,
  "error": "Abbruch durch Benutzer"
}
```

**HTTP Status Codes:**
- `200` - Erfolgreich (auch bei Abbruch durch Benutzer)
- `500` - Server-Fehler

**Hinweise:**
- Dieser Endpunkt öffnet einen GUI-Dialog auf dem Server
- Bei Systemen ohne GUI (z.B. Server Core) wird automatisch ein Fallback auf Texteingabe verwendet
- Der Dialog blockiert die API-Anfrage bis zur Auswahl oder zum Abbruch

## Dashboard-Integration

### JavaScript-Beispiele

**Status abrufen:**
```javascript
fetch('/api/status')
  .then(response => response.json())
  .then(data => {
    console.log('Service Status:', data.isRunning);
    console.log('Queue Size:', data.queueSize);
  });
```

**Konfiguration aktualisieren:**
```javascript
const newConfig = {
  Logging: { Level: 'Debug' }
};

fetch('/api/config', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json'
  },
  body: JSON.stringify(newConfig)
})
.then(response => response.json())
.then(result => {
  if (result.success) {
    console.log('Konfiguration aktualisiert');
  }
});
```

**Real-time Updates (Polling):**
```javascript
function updateStatus() {
  fetch('/api/status')
    .then(response => response.json())
    .then(data => {
      document.getElementById('status').textContent = data.isRunning ? 'Läuft' : 'Gestoppt';
      document.getElementById('queue').textContent = data.queueSize;
    });
}

// Alle 5 Sekunden aktualisieren
setInterval(updateStatus, 5000);
updateStatus(); // Initial laden
```

## PowerShell-Integration

### Status-Abfrage:
```powershell
$status = Invoke-RestMethod -Uri "http://localhost:8080/api/status"
Write-Host "Service läuft: $($status.isRunning)"
Write-Host "Queue-Größe: $($status.queueSize)"
```

### Konfiguration aktualisieren:
```powershell
$config = @{
  Logging = @{
    Level = "Info"
  }
}

Invoke-RestMethod -Uri "http://localhost:8080/api/config" -Method POST -Body ($config | ConvertTo-Json) -ContentType "application/json"
```

### Performance-Monitoring:
```powershell
$perf = Invoke-RestMethod -Uri "http://localhost:8080/api/performance"
Write-Host "CPU: $($perf.CpuUsagePercent)%"
Write-Host "Verfügbarer RAM: $($perf.MemoryAvailableMB) MB"
```

## Fehlerbehandlung

### Häufige HTTP-Status-Codes:
- `200` - OK
- `400` - Bad Request (ungültige Parameter)
- `404` - Not Found (Endpunkt existiert nicht)
- `500` - Internal Server Error (Server-Fehler)

### API-Fehler:
```json
{
  "success": false,
  "error": "Konfiguration konnte nicht gespeichert werden",
  "code": "CONFIG_SAVE_FAILED",
  "details": "Zugriff auf config.json verweigert"
}
```

## Rate Limiting

Die API hat derzeit keine Rate Limiting implementiert. Bei hoher Last sollten entsprechende Maßnahmen implementiert werden.

## Sicherheit

### Empfohlene Sicherheitsmaßnahmen:
1. **HTTPS verwenden** in Produktionsumgebungen
2. **API-Key Authentifizierung** implementieren
3. **IP-Whitelist** für kritische Endpunkte
4. **Input-Validierung** für alle Parameter
5. **Logging** aller API-Zugriffe

## Monitoring

### API-Metriken:
- Response-Zeiten
- Fehler-Raten
- Zugriffsstatistiken
- Endpunkt-Nutzung

### Health Checks:
```bash
# Einfacher Health Check
curl -f http://localhost:8080/api/status
```

## Versionierung

Die API verwendet derzeit keine explizite Versionierung. Bei Änderungen wird das System aktualisiert und die Dokumentation angepasst.

## Support

Bei Fragen zur API:
- **Entwicklungsteam:** dev@company.com
- **Dokumentation:** [Troubleshooting-Guide](Troubleshooting-Guide.md)

---

**API-Version:** 1.0  
**Letzte Aktualisierung:** 23.09.2025  
**Verantwortlich:** Entwicklungsteam</content>
<parameter name="filePath">c:\GitHub\Archive_Watchfolder\guides\API-Dokumentation.md
