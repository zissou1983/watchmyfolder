# Watch Folder Dashboard - Bedienungsanleitung

## 📋 Überblick

Das **Watch Folder Dashboard** ist eine Anwendung, die Dateien in einem Ordner automatisch überwacht und sie basierend auf ihrem Dateityp in verschiedene Zielordner verschiebt.

**Beispiel:** Alle MP4-Dateien, die in `C:\Temp\Incoming` erscheinen, werden automatisch nach `C:\Temp\MAM` verschoben.

---

## 🚀 Programmstart

### Option 1: Schnellstart (empfohlen)
Doppelklick auf **`WatchFolder.bat`** im Programmverzeichnis.

Das Programm öffnet sich nach wenigen Sekunden mit einer grafischen Oberfläche.

### Option 2: Mit PowerShell starten
```powershell
cd C:\Pfad\zum\watchmyfolder
.\WatchFolder.bat
```

---

## 📂 Hauptansicht

Die Anwendung hat mehrere Tabs:

| Tab | Funktion |
|-----|----------|
| **📂 Standard** | Hauptkonfiguration: Watch Folder und Ziele |
| **➕** | Neue benutzerdefinierte Tabs hinzufügen |
| **📋 Verlauf** | Zeigt die letzten verarbeiteten Dateien |
| **⚙️** | Einstellungen und Optionen |

---

## ⚙️ Grundkonfiguration (Standard Tab)

### Watch Folder einstellen

1. Klick auf **"Wählen"** neben "Watch Folder"
2. Wähle den Ordner, den du überwachen möchtest
   - *Standard:* `C:\Temp\Incoming`
3. Aktiviere **"Unterordner überwachen"** wenn Dateien in Unterordnern auch beobachtet werden sollen

### Zielordner konfigurieren

Unter **"Zielordner"** siehst du drei vordefinierte Kategorien:

#### **MAM** (Media)
- Für Mediendateien: MP4, MKV, MOV, AVI, etc.
- Klick auf **"Wählen"** um den Zielordner zu setzen
- **Standardpfad:** `C:\Temp\MAM`

#### **BOX** (Dokumente)
- Für Dokumente: PDF, DOCX, XLSX, etc.
- **Standardpfad:** `C:\Temp\BOX`

#### **Night** (Alles andere)
- Für Dateien, die nicht in MAM oder BOX passen
- Optional: Nur zu bestimmten Zeiten verarbeiten (z.B. nachts)
- **Standardpfad:** `C:\Temp\Night`

---

## ▶️ Überwachung starten/stoppen

### Überwachung aktivieren
1. Klick auf **"▶ Überwachung starten"** im Header (oben)
2. Der Button wird rot und zeigt **"⏹ Überwachung stoppen"**
3. Die Überwachung läuft jetzt im Hintergrund

### Überwachung deaktivieren
1. Klick auf **"⏹ Überwachung stoppen"**
2. Es werden keine neuen Dateien mehr verschoben

---

## 📋 Verlauf anschauen

1. Klick auf den **"📋 Verlauf"** Tab
2. Klick auf **"🔄 Aktualisieren"** um die neuesten Einträge zu laden
3. Du siehst eine Tabelle mit:
   - **Zeit**: Wann die Datei verarbeitet wurde
   - **Dateiname**: Name der verschobenen Datei
   - **Ziel**: Wohin die Datei verschoben wurde

### Verlauf löschen
1. Klick auf **"🗑️ Verlauf leeren"**
2. Bestätige die Frage - der gesamte Verlauf wird gelöscht

---

## 🎯 Benutzerdefinierte Tabs erstellen

Möchtest du zusätzliche Kategorien mit eigenen Regeln? Erstelle einen **benutzerdefinierten Tab**!

### Neuer Tab hinzufügen

1. Klick auf den **"➕"** Button in der Tab-Leiste
2. Gib einen Namen ein (z.B. "Bilder", "Videos", "Archiv")
3. Klick **"Tab erstellen"**

### Tab konfigurieren

1. Klick auf deinen neuen Tab
2. **Watch Folder:** Wähle den Ordner, der überwacht werden soll
3. **Zielordner hinzufügen:**
   - Klick auf **"➕ Ziel hinzufügen"**
   - Gib einen Namen ein (z.B. "Hohe Auflösung")
   - Wähle den Zielordner
4. **Dateitypen hinzufügen:**
   - Wähle einen Zielordner aus (z.B. "Hohe Auflösung")
   - Klick auf **"+ Format hinzufügen"**
   - Gib eine Dateityp ein (z.B. `.mkv`, `.4k`)

### Tab speichern
1. Klick auf **"💾 Speichern"**
2. Die Konfiguration wird gespeichert

### Tab löschen
1. Klick auf **"🗑️ Löschen"**
2. Bestätige - der Tab wird gelöscht

---

## ⚙️ Optionen & Einstellungen

Klick auf den **"⚙️"** Tab für folgende Optionen:

### Design
- **Dark Mode:** Aktiviert das dunkle Farbschema (Standard: aktiviert)

### Systemstart
- **Autostart aktivieren:** Das Programm startet automatisch beim Windows-Start
- *Hinweis:* Die Überwachung muss trotzdem manuell gestartet werden

---

## 💡 Tipps und Best Practice

### Ordnerstruktur planen
```
C:\Temp\
├── Incoming\          ← Watch Folder
├── MAM\               ← Zielordner für Videos
├── BOX\               ← Zielordner für Dokumente
├── Night\             ← Zielordner für sonstiges
└── Archiv\            ← Für alte Dateien
```

### Dateitypen richtig eingeben
- Mit Punkt: `.mp4`, `.pdf`, `.docx` ✅
- Auch akzeptiert: `mp4`, `PDF`, `*.mov` ✅
- Nicht akzeptiert: `movie`, `.` ❌

### Night-Batch für automatische Verarbeitung
1. Klick auf den **Standard** Tab
2. Unter **"Night Folder"** aktiviere **"Nur zu bestimmten Zeiten verarbeiten"**
3. Stelle die Uhrzeit ein (z.B. 20:00 - 06:00)
4. Nur in diesem Zeitfenster werden Dateien nach Night verschoben

---

## 🔧 Häufig gestellte Fragen

### **F: Das Programm startet nicht**
**A:** 
1. Stelle sicher, dass PowerShell 5.1+ installiert ist
2. Versuche, die BAT-Datei als Administrator auszuführen (Rechtsklick)
3. Prüfe, ob die Konfigurationsdatei `config/config.json` existiert

### **F: Dateien werden nicht verschoben**
**A:**
1. Prüfe, ob die Überwachung aktiv ist (Button sollte rot sein)
2. Stelle sicher, dass der Watch Folder korrekt eingestellt ist
3. Prüfe im **Verlauf** Tab ob Fehler angezeigt werden
4. Versuche, die Überwachung zu stoppen und neu zu starten

### **F: Wie kann ich Dateien aus verschlossenen Ordnern verschieben?**
**A:** Das Programm benötigt Schreibberechtigung auf dem Watch Folder und allen Zielordnern. Prüfe die Ordnerberechtigungen (Rechtsklick → Eigenschaften → Sicherheit).

### **F: Können Netzwerkordner überwacht werden?**
**A:** Ja, aber es kann zu Verzögerungen kommen. Das Programm unterstützt SMB-Freigaben (z.B. `\\server\freigabe`).

### **F: Wie kann ich ein Backup machen?**
**A:** Kopiere die Datei `config/config.json` - diese enthält alle deine Einstellungen.

### **F: Kann ich die Konfiguration teilen?**
**A:** Ja! Teile die `config/config.json` Datei mit Kollegen. Sie können diese in ihr Programm-Verzeichnis kopieren.

---

## 🛑 Fehlerbehebung

### Problem: "Kritischer Fehler: JSON-Datei ungültig"
- Die Konfigurationsdatei ist beschädigt
- **Lösung:** Lösche `config/config.json` und starte das Programm neu

### Problem: "Zugriff verweigert"
- Fehlende Berechtigungen auf Ordnern
- **Lösung:** Starte das Programm als Administrator

### Problem: Datei wird nicht verschoben, aber im Verlauf angezeigt
- Wahrscheinlich Namenskonflikt (Datei mit diesem Namen existiert bereits)
- **Lösung:** Die Datei wird mit Nummer umbenannt (z.B. `video_1.mp4`)

---

## 📞 Support

Für weitere Fragen oder Probleme:
- Prüfe die Log-Dateien im Ordner `logs/`
- Kontaktiere deinen Administrator

---

**Version:** 1.0.0  
**Zuletzt aktualisiert:** Dezember 2025
