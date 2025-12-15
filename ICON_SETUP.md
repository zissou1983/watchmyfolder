# 🔍 Watch Folder Icon Setup Guide

## Header Icon ✅
Das Dashboard zeigt jetzt das Watch Folder Icon (`gfx/watcher.ico`) im Header und als Browser-Favicon.

## BAT-Datei mit Icon 🎨

### Option 1: Automatisch (Empfohlen)
Führe diesen Command in PowerShell aus:

```powershell
cd "E:\GitHub\watchmyfolder"
powershell -ExecutionPolicy Bypass -File "WatchFolderLauncher.ps1" -CreateShortcut
```

Dies erstellt eine Verknüpfung `WatchFolder.lnk` mit dem benutzerdefinierten Icon.

### Option 2: Manuell
1. Rechtsklick auf `WatchFolder.bat`
2. Sende an → Desktop (Verknüpfung erstellen)
3. Rechtsklick auf die neue Desktop-Verknüpfung
4. Eigenschaften
5. Button "Symbol ändern..."
6. Durchsuchen: `E:\GitHub\watchmyfolder\gfx\watcher.ico`
7. OK

## Fertig! 🎉
Das Icon wird jetzt in der Taskleiste, dem Desktop und überall angezeigt, wo die Verknüpfung verwendet wird.
