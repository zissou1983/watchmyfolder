# FolderBrowser.ps1 - Ordner-Browser für Watch Folder System
param(
    [string]$Type = "general",  # general, watch, destination, log, backup
    [string]$CurrentPath = "",
    [string]$Description = "",
    [string]$DestinationType = ""  # Für destination type
)

# Module laden
. "$PSScriptRoot\modules\FolderBrowserDialog.ps1"

try {
    $browser = [FolderBrowserDialog]::new()

    if (-not $browser.Success) {
        # Fallback für Systeme ohne GUI
        Write-Host "GUI nicht verfügbar. Bitte Pfad manuell eingeben:" -ForegroundColor Yellow
        $result = Read-Host "Ordner-Pfad"
        if ($result) {
            @{ "success" = $true; "path" = $result.Trim() } | ConvertTo-Json
        } else {
            @{ "success" = $false; "error" = "Kein Pfad eingegeben" } | ConvertTo-Json
        }
        exit
    }

    # Bestimme die Beschreibung basierend auf dem Typ
    switch ($Type) {
        "watch" {
            $result = $browser.BrowseForWatchFolder($CurrentPath)
        }
        "destination" {
            $result = $browser.BrowseForDestinationFolder($DestinationType, $CurrentPath)
        }
        "log" {
            $result = $browser.BrowseForLogFolder($CurrentPath)
        }
        "backup" {
            $result = $browser.BrowseForBackupFolder($CurrentPath)
        }
        default {
            if ($Description) {
                $result = $browser.ShowDialog($Description, "", $CurrentPath)
            } else {
                $result = $browser.ShowDialog("Ordner auswählen", "", $CurrentPath)
            }
        }
    }

    if ($result) {
        @{ "success" = $true; "path" = $result } | ConvertTo-Json
    } else {
        @{ "success" = $false; "error" = "Abbruch durch Benutzer" } | ConvertTo-Json
    }

} catch {
    @{ "success" = $false; "error" = $_.Exception.Message } | ConvertTo-Json
}