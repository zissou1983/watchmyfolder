# Globale Variable für Aktivitäten (in Produktion aus DB/Log-Datei)
$global:Activities = @()

# Standard-Port definieren
$Port = 8080

# Module importieren
. "$PSScriptRoot\modules\PerformanceMonitor.ps1"
. "$PSScriptRoot\modules\Logger.ps1"
. "$PSScriptRoot\modules\FormatClassifier.ps1"
. "$PSScriptRoot\modules\OperationTracker.ps1"  # Vor RoutingEngine laden
. "$PSScriptRoot\modules\RoutingEngine.ps1"
. "$PSScriptRoot\modules\WatchEngine.ps1"

# System.Web für Query-Parameter laden
Add-Type -AssemblyName System.Web

# Funktion zum Hinzufügen neuer Aktivitäten
function Add-Activity {
    param(
        [string]$Title,
        [string]$Description,
        [DateTime]$Timestamp = (Get-Date)
    )
    
    $activity = @{
        "title" = $Title
        "description" = $Description
        "timestamp" = $Timestamp.ToString("yyyy-MM-ddTHH:mm:ss")
    }
    
    # Neue Aktivität am Anfang hinzufügen
    $global:Activities = @($activity) + $global:Activities
    
    # Behalte nur die letzten 50 Aktivitäten
    if ($global:Activities.Count -gt 50) {
        $global:Activities = $global:Activities[0..49]
    }
}

# Beispielaktivitäten hinzufügen
Add-Activity -Title "MXF-Datei verarbeitet" -Description "video001.mxf in MAM verschoben" -Timestamp (Get-Date).AddMinutes(-5)
Add-Activity -Title "PDF-Dokument verarbeitet" -Description "document.pdf in BOX verschoben" -Timestamp (Get-Date).AddMinutes(-10)
Add-Activity -Title "Unbekannte Datei" -Description "unknown.xyz in Night verschoben" -Timestamp (Get-Date).AddMinutes(-15)
Add-Activity -Title "Datei entdeckt" -Description "newfile.txt im Watch Folder" -Timestamp (Get-Date).AddMinutes(-3)

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")

# Performance Monitor initialisieren
$performanceMonitor = New-Object PerformanceMonitor

try {
    $listener.Start()
    Write-Host "Web-Server gestartet auf http://localhost:$Port" -ForegroundColor Green
    Write-Host "Drücken Sie Ctrl+C zum Beenden" -ForegroundColor Yellow
    
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response
        
        try {
            $path = $request.Url.AbsolutePath
            
            # CORS-Header für alle Requests
            $response.Headers.Add("Access-Control-Allow-Origin", "*")
            $response.Headers.Add("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
            $response.Headers.Add("Access-Control-Allow-Headers", "Content-Type")
            
            if ($request.HttpMethod -eq "OPTIONS") {
                # CORS Preflight Request
                $response.StatusCode = 200
                $buffer = [System.Text.Encoding]::UTF8.GetBytes("")
            } elseif ($path -eq "/") {
                # Dashboard HTML
                $response.ContentType = "text/html; charset=utf-8"
                $dashboardPath = "$PSScriptRoot\dashboard\simple-dashboard.html"
                if (Test-Path $dashboardPath) {
                    $html = Get-Content $dashboardPath -Raw -Encoding UTF8
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
                } else {
                    $html = "<h1>Dashboard nicht gefunden</h1><p>simple-dashboard.html fehlt</p>"
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
                }
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
            } elseif ($path -eq "/api/config") {
                # API für Konfiguration
                $response.ContentType = "application/json"
                
                if ($request.HttpMethod -eq "GET") {
                    # Konfiguration laden
                    $configPath = "$PSScriptRoot\..\config\config.json"
                    if (Test-Path $configPath) {
                        $configJson = Get-Content $configPath -Raw -Encoding UTF8
                        $buffer = [System.Text.Encoding]::UTF8.GetBytes($configJson)
                    } else {
                        $buffer = [System.Text.Encoding]::UTF8.GetBytes('{"error": "Konfiguration nicht gefunden"}')
                    }
                } elseif ($request.HttpMethod -eq "POST") {
                    # Konfiguration speichern
                    try {
                        $reader = New-Object System.IO.StreamReader($request.InputStream)
                        $configJson = $reader.ReadToEnd()
                        $configPath = "$PSScriptRoot\..\config\config.json"
                        $configJson | Set-Content $configPath -Encoding UTF8
                        $buffer = [System.Text.Encoding]::UTF8.GetBytes('{"success": true, "message": "Konfiguration gespeichert"}')
                    } catch {
                        $buffer = [System.Text.Encoding]::UTF8.GetBytes(('{"success": false, "error": "' + $_.Exception.Message + '"}'))
                    }
                }
            } elseif ($path -eq "/api/activities") {
                # API für Aktivitäten
                $response.ContentType = "application/json"
                
                $json = $global:Activities | ConvertTo-Json
                if (-not $json) { $json = "[]" }
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
            } elseif ($path -eq "/api/status") {
                # API für Service-Status
                $response.ContentType = "application/json"
                
                $status = @{
                    "isRunning" = $true
                    "queueSize" = 0
                    "uptime" = 3600
                }
                $json = $status | ConvertTo-Json
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
            } elseif ($path -eq "/api/stats") {
                # API für Statistiken
                $response.ContentType = "application/json"
                
                $stats = @{
                    "mamCount" = 0
                    "boxCount" = 0
                    "nightCount" = 0
                    "errorCount" = 0
                    "hourlyData" = @()
                }
                $json = $stats | ConvertTo-Json
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
                # API für aktive Operationen
                $response.ContentType = "application/json"
                
                # Vereinfachte aktive Operationen - in Produktion aus Service
                $operations = @()
                $json = (@{
                    "operations" = $operations
                    "totalCount" = 0
                } | ConvertTo-Json)
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
            } elseif ($path -eq "/api/cancel-operation") {
                # API für Operation abbrechen
                $response.ContentType = "application/json"
                
                if ($request.HttpMethod -eq "POST") {
                    # Query-Parameter extrahieren
                    $query = [System.Web.HttpUtility]::ParseQueryString($request.Url.Query)
                    $operationId = $query["id"]
                    
                    if ($operationId) {
                        Add-Activity -Title "Operation abgebrochen" -Description "Operation $operationId wurde abgebrochen"
                        $json = (@{
                            "success" = $true
                            "message" = "Operation abgebrochen"
                        } | ConvertTo-Json)
                    } else {
                        $json = '{"success":false,"error":"Operation ID required"}'
                    }
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
                } else {
                    $json = '{"success":false,"error":"Method not allowed"}'
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
                }
            } elseif ($path -eq "/api/create-test-file") {
                # API für Test-Datei erstellen
                $response.ContentType = "application/json"
                
                try {
                    # Konfiguration laden
                    $configPath = "$PSScriptRoot\..\config\config.json"
                    $config = Get-Content $configPath -Raw | ConvertFrom-Json
                    
                    $watchFolderPath = $config.WatchFolders[0].Path
                    $testFileName = "test_file_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
                    $testFilePath = Join-Path $watchFolderPath $testFileName
                    
                    # Test-Datei erstellen
                    $testContent = "Test-Datei erstellt am $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
                    $testContent | Set-Content -Path $testFilePath -Encoding UTF8
                    
                    # Aktivität hinzufügen
                    Add-Activity -Title "Test-Datei erstellt" -Description "$testFileName im Watch Folder"
                    
                    $json = (@{
                        "success" = $true
                        "message" = "Test-Datei erstellt: $testFileName"
                        "filePath" = $testFilePath
                    } | ConvertTo-Json)
                    if (-not $json) { $json = '{"success":false,"error":"JSON serialization failed"}' }
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
                } catch {
                    $json = (@{
                        "success" = $false
                        "error" = $_.Exception.Message
                    } | ConvertTo-Json)
                    if (-not $json) { $json = '{"success":false,"error":"Unknown error"}' }
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
                }
            } elseif ($path -eq "/api/formats") {
                # API für Format-Konfiguration
                $response.ContentType = "application/json"
                
                if ($request.HttpMethod -eq "GET") {
                    # Formate laden
                    try {
                        $configPath = "$PSScriptRoot\..\config\config.json"
                        if (Test-Path $configPath) {
                            $config = Get-Content $configPath -Raw | ConvertFrom-Json
                            $formats = if ($config.PSObject.Properties.Name -contains "Formats") {
                                $config.Formats
                            } else {
                                @{
                                    "MAM" = @(".mxf", ".mov", ".mp4", ".avi", ".mkv", ".m4v", ".wav", ".aiff", ".flac", ".mp3", ".aac")
                                    "BOX" = @(".pdf", ".doc", ".docx", ".xls", ".xlsx", ".ppt", ".pptx", ".txt")
                                    "SYSTEM" = @(".tmp", ".log", ".cache", ".db", ".ini", ".sys", ".bim", ".cpi", ".pek", ".xmp", ".xml")
                                }
                            }
                            
                            $json = (@{
                                "success" = $true
                                "formats" = $formats
                            } | ConvertTo-Json -Depth 10)
                        } else {
                            $json = '{"success":false,"error":"Konfiguration nicht gefunden"}'
                        }
                        $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
                    } catch {
                        $json = (@{
                            "success" = $false
                            "error" = $_.Exception.Message
                        } | ConvertTo-Json)
                        $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
                    }
                } elseif ($request.HttpMethod -eq "POST") {
                    # Formate speichern
                    try {
                        $reader = New-Object System.IO.StreamReader($request.InputStream)
                        $jsonData = $reader.ReadToEnd()
                        $data = $jsonData | ConvertFrom-Json
                        
                        if (-not $data.formats) {
                            $json = '{"success":false,"error":"Keine Formate angegeben"}'
                        } else {
                            # Konfiguration laden und aktualisieren
                            $configPath = "$PSScriptRoot\..\config\config.json"
                            if (Test-Path $configPath) {
                                $config = Get-Content $configPath -Raw | ConvertFrom-Json
                            } else {
                                $config = @{}
                            }
                            
                            # Formate aktualisieren
                            $config | Add-Member -MemberType NoteProperty -Name "Formats" -Value $data.formats -Force
                            
                            # Konfiguration speichern
                            $config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
                            
                            # Aktivität hinzufügen
                            Add-Activity -Title "Format-Konfiguration aktualisiert" -Description "$($data.formats.Keys.Count) Format-Kategorien konfiguriert"
                            
                            $json = (@{
                                "success" = $true
                                "message" = "Formate erfolgreich aktualisiert"
                            } | ConvertTo-Json)
                        }
                        $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
                    } catch {
                        $json = (@{
                            "success" = $false
                            "error" = $_.Exception.Message
                        } | ConvertTo-Json)
                        $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
                    }
                }
            } elseif ($path -eq "/api/night-batch/status") {
                # API für Nachtverarbeitung Status
                $response.ContentType = "application/json"
                
                $status = @{
                    "processingWindow" = @{
                        "isActive" = $false
                        "start" = "20:00"
                        "end" = "06:00"
                    }
                    "nightFolder" = @{
                        "exists" = $false
                        "fileCount" = 0
                    }
                    "canStartManually" = $true
                    "lastRun" = $null
                }
                $json = $status | ConvertTo-Json -Depth 10
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
            } elseif ($path -eq "/api/night-batch/start") {
                # API für Nachtverarbeitung starten
                $response.ContentType = "application/json"
                
                if ($request.HttpMethod -eq "POST") {
                    # Nachtverarbeitung starten (vereinfacht)
                    Add-Activity -Title "Nachtverarbeitung gestartet" -Description "Manueller Start über Dashboard"
                    
                    $json = (@{
                        "success" = $true
                        "message" = "Nachtverarbeitung wurde gestartet"
                    } | ConvertTo-Json)
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
                } else {
                    $json = '{"success":false,"error":"Method not allowed"}'
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
                }
            } else {
                # 404
                $response.StatusCode = 404
                $buffer = [System.Text.Encoding]::UTF8.GetBytes("Not Found")
            }
            
            $response.ContentLength64 = $buffer.Length
            $response.OutputStream.Write($buffer, 0, $buffer.Length)
            
        } catch {
            Write-Host "Request Error: $($_.Exception.Message)" -ForegroundColor Red
        } finally {
            $response.Close()
        }
    }
    
} catch {
    Write-Host "Server Error: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    if ($listener.IsListening) {
        $listener.Stop()
    }
    Write-Host "Web-Server gestoppt" -ForegroundColor Yellow
}