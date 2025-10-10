Describe "Quarantine Integration Tests" {
    BeforeAll {
        # Test-Umgebung einrichten
        $script:testRoot = "$env:TEMP\WatchFolderIntegrationTest"
        $script:watchFolder = Join-Path $script:testRoot "Watch"
        $script:mamFolder = Join-Path $script:testRoot "MAM"
        $script:boxFolder = Join-Path $script:testRoot "BOX"
        $script:nightFolder = Join-Path $script:testRoot "Night"
        $script:quarantineFolder = Join-Path $script:testRoot "Quarantine"

        # Ordner erstellen
        $folders = @($script:watchFolder, $script:mamFolder, $script:boxFolder, $script:nightFolder, $script:quarantineFolder)
        foreach ($folder in $folders) {
            if (-not (Test-Path $folder)) {
                New-Item -Path $folder -ItemType Directory -Force | Out-Null
            }
        }

        # Test-Konfiguration
        $script:testConfig = @{
            "WatchFolders" = @(
                @{
                    "Path" = $script:watchFolder
                    "Enabled" = $true
                    "GracePeriod" = 1  # Sehr kurze Karenzzeit für Tests
                }
            )
            "Destinations" = @{
                "MAM" = @{
                    "Path" = $script:mamFolder
                    "Enabled" = $true
                    "PreserveFolderStructure" = $true
                }
                "BOX" = @{
                    "Path" = $script:boxFolder
                    "Enabled" = $true
                    "SanitizeFilenames" = $true
                    "PreserveFolderStructure" = $false
                }
                "Night" = @{
                    "Path" = $script:nightFolder
                    "Enabled" = $true
                    "ProcessingWindow" = @{
                        "Start" = "20:00"
                        "End" = "06:00"
                    }
                }
                "Quarantine" = @{
                    "Path" = $script:quarantineFolder
                    "Enabled" = $true
                    "GroupByErrorType" = $true
                    "PreserveOriginalStructure" = $true
                }
            }
        }

        # Module laden
        . "$PSScriptRoot\..\..\src\modules\Logger.ps1"
        . "$PSScriptRoot\..\..\src\modules\FormatClassifier.ps1"
        . "$PSScriptRoot\..\..\src\modules\RoutingEngine.ps1"
        . "$PSScriptRoot\..\..\src\modules\WatchEngine.ps1"
        . "$PSScriptRoot\..\..\src\modules\PerformanceMonitor.ps1"
    }

    AfterAll {
        # Test-Umgebung aufräumen
        if (Test-Path $script:testRoot) {
            Remove-Item -Path $script:testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context "End-to-End Quarantine Processing" {
        It "Should quarantine files when all destinations fail" {
            $logger = [Logger]::new("$script:testRoot\test.log", "Info")
            $classifier = [FormatClassifier]::new()
            $routingEngine = [RoutingEngine]::new($logger, $script:testConfig, $classifier)

            # Alle Ziele deaktivieren um Quarantäne zu erzwingen
            $script:testConfig.Destinations.MAM.Enabled = $false
            $script:testConfig.Destinations.BOX.Enabled = $false
            $script:testConfig.Destinations.Night.Enabled = $false

            # Test-Dateien erstellen
            $testFiles = @()
            for ($i = 1; $i -le 3; $i++) {
                $fileName = "quarantine_test_$i.mxf"
                $filePath = Join-Path $script:watchFolder $fileName
                $testFile = New-Item -Path $filePath -ItemType File -Force
                "Test content $i" | Set-Content -Path $testFile.FullName -Encoding UTF8
                $testFiles += $testFile
            }

            # Dateien verarbeiten
            foreach ($file in $testFiles) {
                $routingEngine.RouteFile($file)
            }

            # Prüfen ob alle Dateien in Quarantäne verschoben wurden
            $quarantineFiles = Get-ChildItem -Path $script:quarantineFolder -Recurse -File
            $quarantineFiles.Count | Should -Be 3

            $quarantineFileNames = $quarantineFiles.Name
            $quarantineFileNames | Should -Contain "quarantine_test_1.mxf"
            $quarantineFileNames | Should -Contain "quarantine_test_2.mxf"
            $quarantineFileNames | Should -Contain "quarantine_test_3.mxf"

            # Aufräumen
            $quarantineFiles | Remove-Item -Force -ErrorAction SilentlyContinue
        }

        It "Should quarantine files on transfer errors" {
            $logger = [Logger]::new("$script:testRoot\test.log", "Info")
            $classifier = [FormatClassifier]::new()
            $routingEngine = [RoutingEngine]::new($logger, $script:testConfig, $classifier)

            # Konfiguration zurücksetzen
            $script:testConfig.Destinations.MAM.Enabled = $true
            $script:testConfig.Destinations.BOX.Enabled = $true
            $script:testConfig.Destinations.Night.Enabled = $true

            # Ungültiges MAM-Ziel setzen
            $originalMAMPath = $script:testConfig.Destinations.MAM.Path
            $script:testConfig.Destinations.MAM.Path = "Z:\Invalid\Drive\Path"

            # Test-Datei erstellen (als MXF für MAM-Routing)
            $testFile = New-Item -Path "$script:watchFolder\transfer_error_test.mxf" -ItemType File -Force
            "Test content" | Set-Content -Path $testFile.FullName -Encoding UTF8

            # Datei verarbeiten (sollte Transfer-Fehler auslösen)
            $routingEngine.RouteFile($testFile)

            # Konfiguration zurücksetzen
            $script:testConfig.Destinations.MAM.Path = $originalMAMPath

            # Prüfen ob Datei in Quarantäne ist
            $quarantineFiles = Get-ChildItem -Path $script:quarantineFolder -Recurse -File
            $quarantineFiles.Name | Should -Contain "transfer_error_test.mxf"

            # Aufräumen
            $quarantineFiles | Remove-Item -Force -ErrorAction SilentlyContinue
        }

        It "Should maintain folder structure in quarantine" {
            $logger = [Logger]::new("$script:testRoot\test.log", "Info")
            $classifier = [FormatClassifier]::new()
            $routingEngine = [RoutingEngine]::new($logger, $script:testConfig, $classifier)

            # Alle Ziele deaktivieren
            $script:testConfig.Destinations.MAM.Enabled = $false
            $script:testConfig.Destinations.BOX.Enabled = $false
            $script:testConfig.Destinations.Night.Enabled = $false

            # Verschachtelte Ordner-Struktur erstellen
            $subFolder = Join-Path $script:watchFolder "SubFolder"
            if (-not (Test-Path $subFolder)) {
                New-Item -Path $subFolder -ItemType Directory -Force | Out-Null
            }

            $testFile = New-Item -Path "$subFolder\nested_file.mxf" -ItemType File -Force
            "Nested test content" | Set-Content -Path $testFile.FullName -Encoding UTF8

            # Datei verarbeiten
            $routingEngine.RouteFile($testFile)

            # Prüfen ob Ordner-Struktur in Quarantäne erhalten wurde
            $quarantineFiles = Get-ChildItem -Path $script:quarantineFolder -Recurse -File
            $quarantineFiles.Count | Should -Be 1

            # Pfad sollte SubFolder enthalten
            $quarantineFilePath = $quarantineFiles[0].FullName
            $quarantineFilePath | Should -Match "SubFolder"

            # Aufräumen
            $quarantineFiles | Remove-Item -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $subFolder -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context "Quarantine with WatchEngine Integration" {
        It "Should handle quarantine through complete processing pipeline" {
            $logger = [Logger]::new("$script:testRoot\test.log", "Info")
            $watchEngine = [WatchEngine]::new($logger, $script:testConfig)
            $classifier = [FormatClassifier]::new()
            $routingEngine = [RoutingEngine]::new($logger, $script:testConfig, $classifier)

            # WatchEngine mit Routing-Callback konfigurieren
            $watchEngine.FileReadyCallback = {
                param($file)
                $routingEngine.RouteFile($file)
            }

            # Alle Ziele deaktivieren um Quarantäne zu erzwingen
            $script:testConfig.Destinations.MAM.Enabled = $false
            $script:testConfig.Destinations.BOX.Enabled = $false
            $script:testConfig.Destinations.Night.Enabled = $false

            # Test-Datei erstellen
            $testFile = New-Item -Path "$script:watchFolder\watchengine_quarantine_test.mxf" -ItemType File -Force
            "WatchEngine test content" | Set-Content -Path $testFile.FullName -Encoding UTF8

            # Simuliere Datei-Event (normalerweise durch FileSystemWatcher)
            $watchEngine.ProcessFile(@{
                FilePath = $testFile.FullName
                EventType = "Created"
                Timestamp = Get-Date
                RetryCount = 0
            })

            # Prüfen ob Datei in Quarantäne verschoben wurde
            Start-Sleep -Milliseconds 100  # Kurze Pause für Verarbeitung
            $quarantineFiles = Get-ChildItem -Path $script:quarantineFolder -Recurse -File
            $quarantineFiles.Name | Should -Contain "watchengine_quarantine_test.mxf"

            # Aufräumen
            $quarantineFiles | Remove-Item -Force -ErrorAction SilentlyContinue
        }
    }
}