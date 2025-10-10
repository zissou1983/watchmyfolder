Watch Folder MAM/BOX Routing System
Projektdokumentation & Implementierungs-Roadmap
📋 Executive Summary
Projektziel
Entwicklung eines intelligenten Watch Folder Systems, das als automatischer Vorfilter für die Medienarchivierung fungiert. Das System sortiert eingehende Dateien automatisch nach Dateityp und leitet sie entweder an das MAM-System (Media Asset Management) oder an BOX-Upload weiter.

Kernnutzen
Automatisierung: Eliminierung manueller Sortierarbeit
Fehlerreduktion: Verhindert fehlerhafte Uploads ins MAM
Effizienzsteigerung: Optimale Auslastung der Netzwerkressourcen durch Nachtverarbeitung
Strukturerhaltung: Beibehaltung der Ordnerstrukturen beim Transfer
Zeitrahmen
Geschätzte Gesamtdauer: 6-8 Wochen

🎯 Projektbeschreibung
1. Ausgangssituation
Aktuelle Herausforderungen
Manuelle Sortierung von Rohmaterial nach Dateiformaten
Server-Überlastung durch nicht-kompatible Dateien
Zeitaufwändige Nachbearbeitung fehlgeschlagener Uploads
Keine automatische Unterscheidung zwischen MAM-fähigen und BOX-relevanten Dateien
Bestehende Infrastruktur
MAM-Ingest Ordner: Existiert, wird von Moovit betreut (Watch Folder)
BOX-Upload Ordner: Wird von IT eingerichtet (Watch Folder)
Netzwerkumgebung: Windows Server Umgebung mit Active Directory
2. Lösungskonzept
Technische Architektur
[Eingabe] → [Watch Folder] → [Format-Analyse] → [Routing-Engine] → [Zielordner]
                                    ↓
                            [Logging & Monitoring]
Hauptkomponenten
Watch Folder Engine: FileSystemWatcher-basierte Überwachung
Format Classifier: Intelligente Dateityp-Erkennung und Validierung
Routing Logic: Regelbasierte Verteilung an Zielsysteme
Queue Management: Karenzzeit-Verwaltung und Batch-Processing
Monitoring Dashboard: Echtzeit-Statusübersicht
3. Funktionale Anforderungen
Muss-Kriterien
 Automatische Erkennung von MAM-kompatiblen Formaten
 Routing nicht-kompatibler Dateien zu BOX
 Erhaltung der Ordnerstruktur
 Karenzzeit von 10 Minuten für Sofort-Verarbeitung
 Nachtverarbeitung außerhalb der Bürozeiten
 Sonderzeichen-Bereinigung für BOX-Upload
 Logging aller Vorgänge
Kann-Kriterien
 MXF-Validierung
 HTML-Dashboard
 E-Mail-Benachrichtigungen
 Quarantäne-Ordner für fehlerhafte Dateien
 Performance-Monitoring
4. Technische Spezifikationen
Unterstützte MAM-Formate
Video-Container: .mxf, .mp4, .mov, .mts, .m2ts, .ts, .m4v, .mkv, .webm, .mpg, .mpeg, .avi, .3gp, .divx, .dv, .flv, .m2t, .vob, .wmv

BOX-Upload Formate
Audio: .wav, .aif, .aiff, .mp3, .flac, .m4a, .ogg Dokumente: .pdf, .doc, .docx, .txt, .xlsx, .pptx Bilder: .jpg, .jpeg, .png, .tiff, .psd, .raw, .dng Projektdateien: .aep, .prproj, .drp, .edl, .aaf, .omf

Namenskonventionen
MAM: [Archivnummer]%[Titel] (Original beibehalten)
BOX: [Archivnummer]_[Titel] (% durch _ ersetzen)
🚀 Implementierungs-Roadmap
Phase 0: Projektinitialisierung (Woche 1) ✅ ABGESCHLOSSEN
Aufgaben
 Projekt-Repository anlegen
 Entwicklungsumgebung einrichten
 Testumgebung vorbereiten
 Stakeholder-Meeting durchführen
Deliverables
Git Repository ✅
Entwicklungsumgebung-Dokumentation ✅
Kickoff-Protokoll ✅
VSCode Setup ✅
bash
# Ordnerstruktur anlegen
mkdir WatchFolder-System
cd WatchFolder-System
mkdir src, tests, docs, config, logs
git init

# VSCode Workspace erstellen
code .

# Empfohlene Extensions installieren:
# - PowerShell
# - Git Graph
# - Markdown All in One
# - TODO Highlight
Phase 1: Grundgerüst & Konfiguration (Woche 1-2) ✅ ABGESCHLOSSEN
1.1 Konfigurationssystem ✅ IMPLEMENTIERT
Datei: config/config.json ✅

Aufgaben:
 JSON-Schema für Konfiguration erstellen ✅
 Konfigurationslader implementieren ✅
 Validierung der Konfiguration ✅
 Unit-Tests für Konfiguration ✅
1.2 Logging-Framework ✅ IMPLEMENTIERT
Datei: src/modules/Logger.ps1 ✅

Aufgaben:
 Logger-Klasse implementieren ✅
 Rotation-Mechanismus ✅
 Performance-Logging ✅
 Error-Tracking ✅
Meilenstein
✅ Konfiguration und Logging funktionsfähig

Phase 2: Datei-Klassifizierung (Woche 2-3) ✅ ABGESCHLOSSEN
2.1 Format-Erkennung ✅ IMPLEMENTIERT
Datei: src/modules/FormatClassifier.ps1 ✅

Aufgaben:
 Magic Number Detection für Dateitypen ✅
 MXF-Header-Validierung ✅
 FFprobe-Integration ✅
 Performance-Optimierung für große Dateien ✅
2.2 Systemdatei-Filter ✅ IMPLEMENTIERT
Datei: src/modules/SystemFileFilter.ps1 ✅

Aufgaben:
 Kamera-Systemdateien identifizieren ✅
 OS-Systemdateien ausschließen ✅
 Whitelist/Blacklist-Mechanismus ✅
Meilenstein
✅ Zuverlässige Dateiklassifizierung

Phase 3: Watch Folder Engine (Woche 3-4) ✅ ABGESCHLOSSEN
3.1 FileSystemWatcher Implementation ✅ IMPLEMENTIERT
Datei: src/modules/WatchEngine.ps1 ✅

Aufgaben:
 FileSystemWatcher konfigurieren ✅
 Event-Handler implementieren ✅
 Rekursive Ordnerüberwachung ✅
 Memory-Management für große Queues ✅
3.2 Karenzzeit-Management ✅ IMPLEMENTIERT

Aufgaben:
 Timer-basierte Queue-Verarbeitung ✅
 Datei-Lock-Detection ✅
 Größenstabilität prüfen ✅
 Retry-Mechanismus ✅
Meilenstein
✅ Stabile Dateiüberwachung mit Karenzzeit

Phase 4: Routing & Transfer (Woche 4-5) ✅ ABGESCHLOSSEN
4.1 Routing-Engine ✅ IMPLEMENTIERT
Datei: src/modules/RoutingEngine.ps1 ✅

Aufgaben:
 Pfad-Parsing und -Rekonstruktion ✅
 Sonderzeichen-Replacement-Engine ✅
 Atomare Move-Operationen ✅
 Fehlerbehandlung bei Namenskonflikten ✅
4.2 Transfer-Optimierung ✅ IMPLEMENTIERT

Aufgaben:
 Parallel-Processing für mehrere Dateien ✅
 Bandwidth-Throttling ✅
 Resume-Fähigkeit bei Abbrüchen ✅
 Checksummen-Validierung ✅
Meilenstein
✅ Zuverlässiges Datei-Routing

Phase 5: Nachtverarbeitung (Woche 5) ✅ ABGESCHLOSSEN
5.1 Batch-Processor ✅ IMPLEMENTIERT
Datei: src/modules/NightBatch.ps1 ✅

Aufgaben:
 Task Scheduler Integration ✅
 Zeitfenster-Validierung ✅
 Batch-Optimierung ✅
 CPU/IO-Throttling ✅
5.2 Scheduled Tasks ✅ IMPLEMENTIERT
Datei: src/NightBatchRunner.ps1 ✅

Meilenstein
✅ Automatisierte Nachtverarbeitung

Phase 6: Monitoring & Dashboard (Woche 6) ✅ ABGESCHLOSSEN
6.1 Status-Dashboard ✅ IMPLEMENTIERT
Datei: src/dashboard/index.html ✅

Aufgaben:
 HTML/CSS Dashboard ✅
 WebSocket für Real-time Updates ✅
 Chart.js für Statistiken ✅
 Export-Funktionen ✅
6.2 Monitoring-API ✅ IMPLEMENTIERT
Datei: src/api/StatusAPI.ps1 ✅

Aufgaben:
 REST API für Status-Abfragen ✅
 JSON Response ✅
 Performance-Metriken ✅
Meilenstein
✅ Vollständiges Monitoring

Phase 7: Testing & Qualitätssicherung (Woche 7) ✅ ABGESCHLOSSEN
7.1 Unit Tests ✅ IMPLEMENTIERT
Test-Struktur:

tests/
├── unit/
│   ├── Test-FormatClassifier.ps1 ✅
│   ├── Test-RoutingEngine.ps1 ✅
│   └── Test-Logger.ps1 ✅
├── integration/
│   ├── Test-WatchFolder.ps1 ✅
│   └── Test-Transfer.ps1 ✅
└── performance/
    └── Test-LargeFiles.ps1 ✅

Aufgaben:
 Pester-Tests schreiben ✅
 Mock-Objekte erstellen ✅
 Coverage > 80% ✅
 Performance-Tests ✅
7.2 Integrationstests ✅ IMPLEMENTIERT

Meilenstein
✅ Vollständige Testabdeckung

Phase 8: Deployment & Go-Live (Woche 8) ✅ ABGESCHLOSSEN
8.1 Deployment-Vorbereitung ✅ IMPLEMENTIERT
Deployment-Checklist: DEPLOYMENT-CHECKLIST.md ✅

8.2 Installation & Konfiguration ✅ IMPLEMENTIERT
Install-Script: deploy/Install-WatchFolder.ps1 ✅

8.3 Dokumentation ✅ VOLLSTÄNDIG IMPLEMENTIERT
Zu erstellende Dokumente:
 Administratorhandbuch ✅ (guides/Betriebshandbuch.md)
 Troubleshooting-Guide ✅ (guides/Troubleshooting-Guide.md)
 API-Dokumentation ✅ (guides/API-Dokumentation.md)
 Disaster Recovery Plan ✅ (guides/Disaster-Recovery-Plan.md)

8.4 Schulung & Übergabe ✅ BEREIT
Schulungsthemen:
Dashboard-Nutzung ✅
Log-Analyse ✅
Fehlerbehandlung ✅
Wartungsaufgaben ✅

Meilenstein
✅ System produktiv

📊 Projekt-Metriken
KPIs (Key Performance Indicators)
Automatisierungsgrad: >95% aller Dateien ohne manuelle Intervention
Fehlerrate: <1% falsch geroutete Dateien
Performance: >100 Dateien/Minute Verarbeitungsgeschwindigkeit
Verfügbarkeit: 99.9% Uptime
Erfolgs-Kriterien
✅ Keine manuellen Sortierungen mehr nötig
✅ Server-Überlastung verhindert
✅ Reduzierung der Fehlerbehandlung um 90%
✅ Vollständige Nachvollziehbarkeit durch Logging
🛠️ Entwicklungsumgebung
Empfohlene Tools
VSCode Extensions
json
{
    "recommendations": [
        "ms-vscode.powershell",
        "eamodio.gitlens",
        "yzhang.markdown-all-in-one",
        "gruntfuggly.todo-tree",
        "humao.rest-client",
        "ms-vscode.live-server",
        "dbaeumer.vscode-eslint"
    ]
}
PowerShell Module
powershell
# Installation der benötigten Module
Install-Module -Name Pester -Force
Install-Module -Name PSScriptAnalyzer -Force
Install-Module -Name PoshLog -Force
Git Workflow
Branch-Strategie
main
├── develop
│   ├── feature/format-classifier
│   ├── feature/watch-engine
│   └── feature/dashboard
└── release/v1.0.0
Commit-Konventionen
feat: Neue Funktion
fix: Fehlerbehebung
docs: Dokumentation
style: Formatierung
refactor: Code-Umstrukturierung
test: Tests hinzufügen
chore: Wartungsarbeiten
🚨 Risikomanagement
Identifizierte Risiken
Risiko	Wahrscheinlichkeit	Impact	Mitigation
MXF-Validierung fehlerhaft	Mittel	Hoch	Fallback auf einfache Extension-Prüfung
Performance-Probleme bei vielen Dateien	Niedrig	Mittel	Batch-Processing und Queuing
Netzwerkausfall während Transfer	Mittel	Niedrig	Retry-Mechanismus
Fehlerhafte Konfiguration	Niedrig	Hoch	Validierung und Defaults
📞 Support & Wartung
Wartungsfenster
Regulär: Sonntags 02:00 - 06:00 Uhr
Notfall-Patches: Nach Bedarf mit 2h Vorlaufzeit
Eskalationspfad
Level 1: Automatische Fehlerbehandlung
Level 2: IT-Support Team
Level 3: Entwicklungsteam
Level 4: Externe Consultants (Moovit für MAM)
Monitoring-Alerts
powershell
# Alert-Konfiguration
@{
    "QueueÜberlauf" = @{
        "Threshold" = 1000
        "Action" = "Email an Admin"
    }
    "FehlerRate" = @{
        "Threshold" = 5
        "TimeWindow" = "10 Minuten"
        "Action" = "SMS an Bereitschaft"
    }
}
📝 Anhang
A. Beispiel-Konfigurationsdateien
[Vollständige JSON-Schemas und Beispiele]

B. API-Referenz
[Detaillierte API-Dokumentation]

C. Troubleshooting-Matrix
[Häufige Probleme und Lösungen]

D. Performance-Tuning Guide
[Optimierungsempfehlungen]

✅ Abschluss-Checkliste
Vor dem Go-Live müssen alle folgenden Punkte erfüllt sein:

 Alle Tests erfolgreich (>80% Coverage)
 Dokumentation vollständig
 Schulungen durchgeführt
 Backup-Strategie implementiert
 Monitoring aktiv
 Rollback-Plan getestet
 Stakeholder-Abnahme erfolgt
 Produktionsumgebung vorbereitet
 Service Level Agreement definiert
 Go-Live-Kommunikation versendet
## 🎉 Finale Version (Oktober 2025)

### Zusätzlich implementiert:
- ✅ **Einfacher Batch-Launcher** (WatchFolder.bat) - zuverlässig und unkompliziert
- ✅ **Electron-Dashboard** mit nativer Windows-UI
- ✅ **Benutzerdefinierte Zielordner** - Unbegrenzte Format-Konfigurationen
- ✅ **Professioneller Installer** - Program Files Installation
- ✅ **Automatischer Node.js-Fallback** - Web-Dashboard ohne Dependencies
- ✅ **Ein-Klick-Start** - Keine komplexe Konfiguration nötig

### Aufräumung:
- 🗑️ **27+ alte Versionen** in trash/ archiviert
- 📋 **Klare Dokumentation** für Endbenutzer
- 🎯 **Production-Ready** - Sofort einsetzbar

---

**Dokumentversion**: 5.0 (Final)  
**Erstellt**: September 2025  
**Finale Version**: Oktober 2025  
**Autor**: Malte Metzner  
**Status**: ✅ **ABGESCHLOSSEN - PRODUCTION READY**

🎊 **Mission Complete: Von Konzept zur professionellen Windows-Anwendung!**

