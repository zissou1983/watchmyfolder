class FolderBrowserDialog {
    [object]$Dialog
    [string]$SelectedPath
    [bool]$Success

    FolderBrowserDialog() {
        # Überprüfe ob Windows Forms verfügbar ist
        try {
            Add-Type -AssemblyName System.Windows.Forms
            $this.Dialog = New-Object System.Windows.Forms.FolderBrowserDialog
            $this.Success = $true
        } catch {
            $this.Success = $false
            Write-Warning "FolderBrowserDialog nicht verfügbar: $($_.Exception.Message)"
        }
    }

    [string] ShowDialog([string]$description = "Ordner auswählen", [string]$rootFolder = "", [string]$selectedPath = "") {
        if (-not $this.Success) {
            # Fallback: Verwende Read-Host für Konsolen-Eingabe
            Write-Host "$description (aktuell: $selectedPath):" -ForegroundColor Yellow
            $newPath = Read-Host "Neuer Pfad"
            if ($newPath -and $newPath.Trim()) {
                return $newPath.Trim()
            }
            return $selectedPath
        }

        # Konfiguriere den Dialog
        $this.Dialog.Description = $description
        $this.Dialog.ShowNewFolderButton = $true

        # Setze Root-Folder falls angegeben
        if ($rootFolder -and (Test-Path $rootFolder)) {
            $this.Dialog.RootFolder = [System.Environment+SpecialFolder]::Desktop
            $this.Dialog.SelectedPath = $rootFolder
        }

        # Setze SelectedPath falls angegeben
        if ($selectedPath -and (Test-Path $selectedPath)) {
            $this.Dialog.SelectedPath = $selectedPath
        }

        # Zeige den Dialog
        $result = $this.Dialog.ShowDialog()

        if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
            $this.SelectedPath = $this.Dialog.SelectedPath
            return $this.SelectedPath
        }

        return $null
    }

    [string] BrowseForWatchFolder([string]$currentPath = "") {
        $description = "Watch Folder auswählen - Ordner, der auf neue Dateien überwacht werden soll"
        return $this.ShowDialog($description, "", $currentPath)
    }

    [string] BrowseForDestinationFolder([string]$destinationType, [string]$currentPath = "") {
        $description = "$destinationType Zielordner auswählen - Ordner für $destinationType-Dateien"
        return $this.ShowDialog($description, "", $currentPath)
    }

    [string] BrowseForLogFolder([string]$currentPath = "") {
        $description = "Log-Ordner auswählen - Ordner für System-Logs"
        return $this.ShowDialog($description, "", $currentPath)
    }

    [string] BrowseForBackupFolder([string]$currentPath = "") {
        $description = "Backup-Ordner auswählen - Ordner für Konfigurations-Backups"
        return $this.ShowDialog($description, "", $currentPath)
    }

    # Statische Hilfsmethode für einfache Verwendung
    static [string] Browse([string]$description = "Ordner auswählen", [string]$currentPath = "") {
        $browser = [FolderBrowserDialog]::new()
        return $browser.ShowDialog($description, "", $currentPath)
    }
}