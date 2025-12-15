# Watch Folder Launcher Script
# This script launches WatchFolder.bat with custom icon support via Windows shortcut

param(
    [switch]$CreateShortcut
)

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$batPath = Join-Path $scriptPath "WatchFolder.bat"
$iconPath = Join-Path $scriptPath "gfx\watcher.ico"
$shortcutPath = Join-Path $scriptPath "WatchFolder.lnk"

# If -CreateShortcut is specified, create a shortcut with the icon
if ($CreateShortcut) {
    Write-Host "Creating Watch Folder shortcut with icon..."
    
    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($shortcutPath)
    $Shortcut.TargetPath = $batPath
    $Shortcut.WorkingDirectory = $scriptPath
    $Shortcut.IconLocation = $iconPath
    $Shortcut.WindowStyle = 1  # Normal window
    $Shortcut.Description = "Watch Folder Dashboard Launcher"
    $Shortcut.Save()
    
    Write-Host "Shortcut created: $shortcutPath"
    Write-Host "You can now use this shortcut to launch Watch Folder with the custom icon."
    exit 0
}

# Otherwise, just run the BAT
Write-Host "Launching Watch Folder..."
& $batPath
