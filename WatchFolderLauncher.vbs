' Watch Folder Launcher with Icon Support
' This VBS script launches WatchFolder.bat with the watcher.ico icon

Set objShell = CreateObject("WScript.Shell")
Set objFSO = CreateObject("Scripting.FileSystemObject")

' Get the directory of this script
strScriptPath = objShell.CurrentDirectory
batPath = objShell.CurrentDirectory & "\WatchFolder.bat"

' Check if BAT exists
If objFSO.FileExists(batPath) Then
    ' Launch BAT in hidden window
    objShell.Run """" & batPath & """", 0, False
Else
    ' Fallback: Show error
    objShell.Popup "WatchFolder.bat not found!", 5, "Watch Folder Error", 48
End If
