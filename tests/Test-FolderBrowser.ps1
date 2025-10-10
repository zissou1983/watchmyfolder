# Test-FolderBrowser.ps1 - Test für FolderBrowserDialog
. "$PSScriptRoot\modules\FolderBrowserDialog.ps1"

Write-Host "Teste FolderBrowserDialog..." -ForegroundColor Green

$browser = [FolderBrowserDialog]::new()

if ($browser.Success) {
    Write-Host "✅ FolderBrowserDialog erfolgreich initialisiert" -ForegroundColor Green

    # Teste statische Methode
    Write-Host "Teste statische Browse-Methode..." -ForegroundColor Yellow
    $result = [FolderBrowserDialog]::Browse("Test-Ordner auswählen", "C:\Temp")

    if ($result) {
        Write-Host "✅ Ordner ausgewählt: $result" -ForegroundColor Green
    } else {
        Write-Host "ℹ️  Abbruch durch Benutzer oder Fehler" -ForegroundColor Yellow
    }

} else {
    Write-Host "❌ FolderBrowserDialog nicht verfügbar (GUI nicht unterstützt)" -ForegroundColor Red
    Write-Host "Teste Fallback..." -ForegroundColor Yellow

    # Simuliere Fallback
    Write-Host "Fallback: Bitte Pfad manuell eingeben:" -ForegroundColor Yellow
    $manualPath = Read-Host "Ordner-Pfad"
    if ($manualPath) {
        Write-Host "✅ Manueller Pfad eingegeben: $manualPath" -ForegroundColor Green
    }
}

Write-Host "Test abgeschlossen." -ForegroundColor Green