# FolderDialogLauncher.ps1 - Startet FolderBrowserDialog in separatem Prozess
param(
    [string]$Type = "general",
    [string]$CurrentPath = "",
    [string]$Description = "",
    [string]$DestinationType = ""
)

# Assembly laden
Add-Type -AssemblyName System.Windows.Forms

try {
    # FolderBrowserDialog erstellen
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowser.ShowNewFolderButton = $true

    # Beschreibung bestimmen
    if (-not $Description) {
        switch ($Type) {
            "watch" { $Description = "Watch Folder auswählen - Ordner, der auf neue Dateien überwacht werden soll" }
            "destination" { $Description = "$DestinationType Zielordner auswählen - Ordner für $DestinationType-Dateien" }
            "log" { $Description = "Log-Ordner auswählen - Ordner für System-Logs" }
            "backup" { $Description = "Backup-Ordner auswählen - Ordner für Konfigurations-Backups" }
            default { $Description = "Ordner auswählen" }
        }
    }
    $folderBrowser.Description = $Description

    # Aktuellen Pfad setzen falls vorhanden
    if ($CurrentPath -and (Test-Path $CurrentPath)) {
        $folderBrowser.SelectedPath = $CurrentPath
    }

    # Dialog anzeigen
    $result = $folderBrowser.ShowDialog()

    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        $selectedPath = $folderBrowser.SelectedPath
        @{ "success" = $true; "path" = $selectedPath } | ConvertTo-Json
    } else {
        @{ "success" = $false; "error" = "Abbruch durch Benutzer" } | ConvertTo-Json
    }
} catch {
    @{ "success" = $false; "error" = $_.Exception.Message } | ConvertTo-Json
}