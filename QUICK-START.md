# 🚀 Watch Folder - Quick Start Guide

## Sofortiger Start (30 Sekunden)

### Schritt 1: EXE ausführen
```cmd
# Doppelklick auf:
WatchFolder.exe
```

### Schritt 2: Dashboard öffnet sich
- **Mit Node.js**: Electron-Fenster (natives App-Gefühl)
- **Ohne Node.js**: Browser-Dashboard (http://localhost:8080)

### Schritt 3: Fertig!
- Backend-Service läuft versteckt im Hintergrund
- Dashboard zeigt Live-Status
- Datei-Überwachung ist aktiv

## 📋 Was du siehst:

### Dashboard-Bereiche:
1. **Watch Folder Konfiguration** - Überwachter Ordner einstellen
2. **Zielordner & Dateiformate** - MAM, BOX, eigene Ordner konfigurieren
3. **Nachtverarbeitung** - Zeitfenster für Batch-Jobs
4. **Konfiguration speichern** - Änderungen anwenden

### Neue Zielordner hinzufügen:
1. Klick auf "➕ Neuen Zielordner hinzufügen"
2. Name eingeben (z.B. "ARCHIVE")
3. Dateiformate zuweisen (z.B. ".zip", ".rar")
4. "Übernehmen" klicken

## 🎯 Typische Konfiguration:

### Standard-Setup:
- **Watch Folder**: `C:\Temp\Incoming`
- **MAM-Ziel**: `C:\Temp\MAM` (Videos, Audio)
- **BOX-Ziel**: `C:\Temp\BOX` (Dokumente)
- **Quarantäne**: `C:\Temp\Quarantine` (Unbekannte Dateien)

### Eigene Zielordner:
- **ARCHIVE** → `.zip`, `.rar`, `.7z`
- **BACKUP** → `.bak`, `.old`
- **TEMP** → `.tmp`, `.temp`

## ⚡ Sofort-Test:

1. **Datei in Watch Folder** legen
2. **Dashboard beobachten** - Live-Verarbeitung
3. **Zielordner prüfen** - Datei automatisch verschoben

## 🆘 Probleme?

### EXE startet nicht:
```cmd
# Backup verwenden:
WatchFolder.bat
```

### Node.js fehlt:
- Automatischer Fallback auf Web-Dashboard
- Oder Node.js installieren: https://nodejs.org/

### Dashboard lädt nicht:
- Firewall prüfen (Port 8080/8082)
- Als Administrator starten

## 📦 Installation (optional):

Für dauerhafte Installation:
```cmd
# Als Administrator:
Install.bat
```

**Das war's! Der Watch Folder Service läuft jetzt professionell!** 🎉

---
**Tipp**: Das Dashboard zeigt alle Aktionen live an - perfekt zum Testen und Überwachen!