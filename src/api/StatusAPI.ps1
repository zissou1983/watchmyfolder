# Vereinfachte StatusAPI für Operation Tracking
class StatusAPI {
    [System.Net.HttpListener]$Listener
    [Logger]$Logger
    [hashtable]$Service
    [bool]$IsRunning
    [System.Collections.Generic.List[hashtable]]$History
    [string]$HistoryFilePath

    StatusAPI([Logger]$Logger, [hashtable]$Service, [int]$Port = 8080) {
        $this.Logger = $Logger
        $this.Service = $Service
        $this.Listener = New-Object System.Net.HttpListener
        $this.Listener.Prefixes.Add("http://+:$Port/")
        $this.Listener.Prefixes.Add("http://127.0.0.1:$Port/")
        $this.IsRunning = $false
        $this.History = New-Object System.Collections.Generic.List[hashtable]
        # HistoryFilePath: src/api im Job, also 3x Parent-Verzeichnis + logs
        $this.HistoryFilePath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "logs\history.json"
        $this.LoadHistory()
    }

    [void] Start() {
        try {
            $this.Listener.Start()
            $this.IsRunning = $true
            $this.Logger.Info("Status API gestartet auf: $($this.Listener.Prefixes[0])", @{})

            while ($this.IsRunning -and $this.Listener.IsListening) {
                $context = $this.Listener.GetContext()
                $this.HandleRequest($context)
            }
        } catch {
            $this.Logger.Error("Status API Fehler: $($_.Exception.Message)", @{ "Exception" = $_.Exception.Message })
        }
    }

    [void] Stop() {
        $this.IsRunning = $false
        if ($this.Listener.IsListening) {
            $this.Listener.Stop()
        }
        $this.Logger.Info("Status API gestoppt", @{})
    }

    [void] HandleRequest([System.Net.HttpListenerContext]$Context) {
        $request = $Context.Request
        $response = $Context.Response

        try {
            $response.Headers.Add("Access-Control-Allow-Origin", "*")

            if ($request.Url.AbsolutePath -eq "/") {
                $response.ContentType = "text/html"
                $responseData = $this.GetDashboard()
            } else {
                $response.ContentType = "application/json"
            }

            $path = $request.Url.AbsolutePath
            $method = $request.HttpMethod

            $responseData = switch ($path) {
                "/api/status" { $this.GetStatus() }
                "/api/active-operations" { $this.GetActiveOperations() }
                "/api/cancel-operation" { $this.CancelOperation($request) }
                "/api/create-test-file" { $this.CreateTestFile($request) }
                "/api/history" { $this.GetHistory() }
                "/api/config" {
                    if ($method -eq "GET") { $this.GetConfig() }
                    elseif ($method -eq "POST") { $this.UpdateConfig($request) }
                    else { @{ "error" = "Method not allowed" } }
                }
                "/api/formats" {
                    if ($method -eq "GET") { $this.GetFormats() }
                    elseif ($method -eq "POST") { $this.UpdateFormats($request) }
                    else { @{ "error" = "Method not allowed" } }
                }
                "/" { $this.GetDashboard() }
                default { @{ "error" = "Endpoint nicht gefunden" } }
            }

            if ($path -eq "/") {
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($responseData)
            } else {
                $json = $responseData | ConvertTo-Json -Depth 10
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
            }

            $response.ContentLength64 = $buffer.Length
            $response.OutputStream.Write($buffer, 0, $buffer.Length)

        } catch {
            $this.Logger.Error("API Request Fehler: $($_.Exception.Message)", @{ "Exception" = $_.Exception.Message })
            $response.StatusCode = 500
        } finally {
            $response.Close()
        }
    }

    [hashtable] GetStatus() {
        return @{
            "isRunning" = $this.Service.IsRunning
            "queueSize" = if ($this.Service.WatchEngine) { $this.Service.WatchEngine.FileQueue.Count } else { 0 }
            "uptime" = 3600
        }
    }

    [hashtable] GetConfig() {
        try {
            if ($this.Service.Config) {
                # Erstelle eine Kopie der Konfiguration
                $configCopy = $this.Service.Config | ConvertTo-Json -Depth 10 | ConvertFrom-Json
                return $configCopy
            } else {
                # Lade Konfiguration aus Datei
                $configPath = "$PSScriptRoot\..\..\config\config.json"
                if (Test-Path $configPath) {
                    $config = Get-Content $configPath -Encoding UTF8 | ConvertFrom-Json
                    return $config
                } else {
                    return @{ "error" = "Konfigurationsdatei nicht gefunden" }
                }
            }
        } catch {
            $this.Logger.Error("Fehler beim Abrufen der Konfiguration: $($_.Exception.Message)", @{ "Exception" = $_.Exception.Message })
            return @{ "error" = $_.Exception.Message }
        }
    }

    [hashtable] UpdateConfig([System.Net.HttpListenerRequest]$Request) {
        try {
            $reader = New-Object System.IO.StreamReader($Request.InputStream)
            $jsonData = $reader.ReadToEnd()
            $data = $jsonData | ConvertFrom-Json

            # Speichere die neue Konfiguration
            $configPath = "$PSScriptRoot\..\..\config\config.json"
            $data | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8

            # Aktualisiere die Service-Konfiguration
            if ($this.Service) {
                $this.Service.Config = $data
            }

            $this.Logger.Info("Konfiguration aktualisiert", @{})

            return @{
                "success" = $true
                "message" = "Konfiguration erfolgreich gespeichert"
            }
        } catch {
            $this.Logger.Error("Fehler beim Aktualisieren der Konfiguration: $($_.Exception.Message)", @{ "Exception" = $_.Exception.Message })
            return @{
                "success" = $false
                "error" = $_.Exception.Message
            }
        }
    }

    [hashtable] GetActiveOperations() {
        if ($this.Service.OperationTracker) {
            return @{
                "operations" = $this.Service.OperationTracker.GetActiveOperations()
                "totalCount" = $this.Service.OperationTracker.GetActiveOperations().Count
            }
        } else {
            return @{
                "operations" = @()
                "totalCount" = 0
            }
        }
    }

    [hashtable] CancelOperation([System.Net.HttpListenerRequest]$Request) {
        try {
            # Einfache Query-Parameter Extraktion
            $query = $Request.Url.Query
            if ($query -match 'id=([^&]+)') {
                $operationId = $matches[1]
            } else {
                return @{ "success" = $false; "error" = "Operation ID required" }
            }

            if ($this.Service.OperationTracker) {
                $this.Service.OperationTracker.CancelOperation($operationId)
                return @{ "success" = $true; "message" = "Operation cancelled" }
            } else {
                return @{ "success" = $false; "error" = "Operation tracker not available" }
            }
        } catch {
            return @{ "success" = $false; "error" = $_.Exception.Message }
        }
    }

    [hashtable] CreateTestFile([System.Net.HttpListenerRequest]$Request) {
        try {
            # Hole den ersten überwachten Ordner aus der Konfiguration
            $watchFolders = $this.Service.Config.WatchFolders
            if (-not $watchFolders -or $watchFolders.Count -eq 0) {
                return @{ "success" = $false; "error" = "Keine überwachten Ordner konfiguriert" }
            }

            $targetFolder = $watchFolders[0].Path
            if (-not (Test-Path $targetFolder)) {
                return @{ "success" = $false; "error" = "Überwachter Ordner existiert nicht: $targetFolder" }
            }

            # Erstelle eine eindeutige Test-Datei
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $fileName = "test_file_$timestamp.txt"
            $filePath = Join-Path $targetFolder $fileName

            # Erstelle Test-Inhalt
            $testContent = @"
Test-Datei erstellt am $(Get-Date)
Dies ist eine automatisch generierte Test-Datei für das Watch Folder System.
Zeitstempel: $timestamp
"@

            # Schreibe die Datei
            $testContent | Out-File -FilePath $filePath -Encoding UTF8

            $this.Logger.Info("Test-Datei erstellt: $filePath", @{ "FilePath" = $filePath; "Type" = "test" })

            return @{
                "success" = $true
                "message" = "Test-Datei erfolgreich erstellt"
                "filePath" = $filePath
                "fileName" = $fileName
            }
        } catch {
            $this.Logger.Error("Fehler beim Erstellen der Test-Datei: $($_.Exception.Message)", @{ "Exception" = $_.Exception.Message })
            return @{ "success" = $false; "error" = $_.Exception.Message }
        }
    }

    [hashtable] GetFormats() {
        try {
            $formats = if ($this.Service.Config -and $this.Service.Config.PSObject.Properties.Name -contains "Formats") {
                $this.Service.Config["Formats"]
            } else {
                @{
                    "MAM" = @(".mxf", ".mp4", ".mov", ".mts", ".m2ts", ".ts", ".m4v", ".mkv", ".webm", ".mpg", ".mpeg", ".avi", ".3gp", ".divx", ".dv", ".flv", ".m2t", ".vob", ".wmv")
                    "BOX" = @(".wav", ".aif", ".aiff", ".mp3", ".flac", ".m4a", ".ogg", ".pdf", ".doc", ".docx", ".txt", ".xlsx", ".pptx", ".jpg", ".jpeg", ".png", ".tiff", ".psd", ".raw", ".dng", ".aep", ".prproj", ".drp", ".edl", ".aaf", ".omf")
                    "SYSTEM" = @(".tmp", ".log", ".cache", ".db", ".ini", ".sys", ".bim", ".cpi", ".pek", ".xmp", ".xml")
                }
            }

            return @{
                "success" = $true
                "formats" = $formats
            }
        } catch {
            return @{
                "success" = $false
                "error" = $_.Exception.Message
            }
        }
    }

    [hashtable] UpdateFormats([System.Net.HttpListenerRequest]$Request) {
        try {
            $reader = New-Object System.IO.StreamReader($Request.InputStream)
            $jsonData = $reader.ReadToEnd()
            $data = $jsonData | ConvertFrom-Json

            if (-not $data.formats) {
                return @{ "success" = $false; "error" = "Keine Formate angegeben" }
            }

            # Aktualisiere die Konfiguration
            $this.Service.Config | Add-Member -MemberType NoteProperty -Name "Formats" -Value $data.formats -Force

            # Speichere die Konfiguration
            $configPath = "$PSScriptRoot\..\..\config\config.json"
            $this.Service.Config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8

            # Aktualisiere den FormatClassifier
            if ($this.Service.Classifier) {
                $this.Service.Classifier.Config = $this.Service.Config
                $this.Service.Classifier.InitializeFormatDatabase()
            }

            $this.Logger.Info("Formate aktualisiert", @{ "UpdatedFormats" = $data.formats.Keys -join ", " })

            return @{
                "success" = $true
                "message" = "Formate erfolgreich aktualisiert"
            }
        } catch {
            $this.Logger.Error("Fehler beim Aktualisieren der Formate: $($_.Exception.Message)", @{ "Exception" = $_.Exception.Message })
            return @{
                "success" = $false
                "error" = $_.Exception.Message
            }
        }
    }

    [void] AddHistoryEntry([string]$FileName, [string]$SourceFolder, [string]$DestinationFolder) {
        try {
            $entry = @{
                "timestamp" = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                "timestampMs" = [int64](Get-Date -UFormat %s)*1000
                "filename" = $FileName
                "source" = $SourceFolder
                "destination" = $DestinationFolder
                "message" = "$FileName von $SourceFolder in $DestinationFolder bewegt."
            }
            
            $this.History.Add($entry)
            $this.SaveHistory()
            
            # Nur die letzten 100 Einträge behalten
            if ($this.History.Count -gt 100) {
                $this.History.RemoveAt(0)
                $this.SaveHistory()
            }
        } catch {
            $this.Logger.Error("Fehler beim Hinzufügen des History-Eintrags: $($_.Exception.Message)", @{})
        }
    }

    [void] LoadHistory() {
        try {
            if (Test-Path $this.HistoryFilePath) {
                $json = Get-Content $this.HistoryFilePath -Raw -ErrorAction SilentlyContinue
                if ($json) {
                    $entries = $json | ConvertFrom-Json -AsHashtable -ErrorAction SilentlyContinue
                    if ($entries -is [array]) {
                        foreach ($entry in $entries) {
                            $this.History.Add($entry)
                        }
                    } elseif ($entries) {
                        $this.History.Add($entries)
                    }
                }
            }
        } catch {
            $this.Logger.Error("Fehler beim Laden der History: $($_.Exception.Message)", @{})
        }
    }

    [void] SaveHistory() {
        try {
            $historyDir = Split-Path $this.HistoryFilePath
            if (!(Test-Path $historyDir)) {
                New-Item -ItemType Directory -Path $historyDir -Force | Out-Null
            }
            
            $sortedHistory = $this.History | Sort-Object timestampMs -Descending
            $json = $sortedHistory | ConvertTo-Json -Depth 10
            Set-Content -Path $this.HistoryFilePath -Value $json -Force -ErrorAction SilentlyContinue
        } catch {
            $this.Logger.Error("Fehler beim Speichern der History: $($_.Exception.Message)", @{})
        }
    }

    [hashtable] GetHistory() {
        try {
            # Wenn die History leer ist, versuche von Datei zu laden
            if ($this.History.Count -eq 0) {
                $this.LoadHistory()
            }

            # Neueste Einträge zuerst
            $sortedHistory = $this.History | Sort-Object timestampMs -Descending
            
            return @{
                "success" = $true
                "history" = $sortedHistory
                "totalEntries" = $this.History.Count
            }
        } catch {
            $this.Logger.Error("Fehler beim Abrufen der History: $($_.Exception.Message)", @{})
            return @{
                "success" = $false
                "error" = $_.Exception.Message
                "history" = @()
            }
        }
    }

    [string] GetDashboard() {
        # Dashboard HTML wird aus separater Datei geladen
        $dashboardPath = Join-Path (Split-Path $PSScriptRoot -Parent) "dashboard\index.html"
        if (Test-Path $dashboardPath) {
            return Get-Content $dashboardPath -Raw -Encoding UTF8
        } else {
            return "<html><body><h1>Dashboard nicht gefunden: $dashboardPath</h1><p>PSScriptRoot: $PSScriptRoot</p></body></html>"
        }
    }
}
