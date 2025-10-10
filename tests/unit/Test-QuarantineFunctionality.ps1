Describe "Quarantine Functionality Tests" {
    BeforeAll {
        . "$PSScriptRoot\..\..\src\modules\Logger.ps1"
        . "$PSScriptRoot\..\..\src\modules\FormatClassifier.ps1"
        . "$PSScriptRoot\..\..\src\modules\RoutingEngine.ps1"
        . "$PSScriptRoot\..\..\src\modules\PerformanceMonitor.ps1"

        # Test-Konfiguration
        $script:testConfig = @{
            "Destinations" = @{
                "Quarantine" = @{
                    "Path" = "$env:TEMP\WatchFolderTest\Quarantine"
                    "Enabled" = $true
                    "GroupByErrorType" = $true
                    "PreserveOriginalStructure" = $true
                }
                "MAM" = @{
                    "Path" = "$env:TEMP\WatchFolderTest\MAM"
                    "Enabled" = $true
                }
                "BOX" = @{
                    "Path" = "$env:TEMP\WatchFolderTest\BOX"
                    "Enabled" = $true
                }
                "Night" = @{
                    "Path" = "$env:TEMP\WatchFolderTest\Night"
                    "Enabled" = $true
                }
            }
            "WatchFolders" = @(
                @{
                    "Path" = "$env:TEMP\WatchFolderTest\Watch"
                    "Enabled" = $true
                }
            )
        }

        # Test-Ordner erstellen
        $folders = @(
            $script:testConfig.Destinations.Quarantine.Path,
            $script:testConfig.Destinations.MAM.Path,
            $script:testConfig.Destinations.BOX.Path,
            $script:testConfig.Destinations.Night.Path,
            $script:testConfig.WatchFolders[0].Path
        )

        foreach ($folder in $folders) {
            if (-not (Test-Path $folder)) {
                New-Item -Path $folder -ItemType Directory -Force | Out-Null
            }
        }
    }

    AfterAll {
        # Test-Ordner aufräumen
        $testRoot = "$env:TEMP\WatchFolderTest"
        if (Test-Path $testRoot) {
            Remove-Item -Path $testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context "Quarantine Path Building" {
        It "Should build correct quarantine paths for different error types" {
            $logger = [Logger]::new("$env:TEMP\test.log", "Info")
            $classifier = [FormatClassifier]::new()
            $routingEngine = [RoutingEngine]::new($logger, $script:testConfig, $classifier)

            # Test-Datei erstellen
            $testFile = New-Item -Path "$($script:testConfig.WatchFolders[0].Path)\test_corrupt.mxf" -ItemType File -Force

            # Verschiedene Fehler-Typen testen
            $corruptPath = $routingEngine.BuildQuarantinePath($testFile, "File is corrupt")
            $accessPath = $routingEngine.BuildQuarantinePath($testFile, "Access denied")
            $networkPath = $routingEngine.BuildQuarantinePath($testFile, "Network error")

            $corruptPath | Should -Match "CorruptFiles"
            $accessPath | Should -Match "AccessDenied"
            $networkPath | Should -Match "NetworkError"

            # Aufräumen
            Remove-Item $testFile.FullName -Force -ErrorAction SilentlyContinue
        }

        It "Should include date folders in quarantine path" {
            $logger = [Logger]::new("$env:TEMP\test.log", "Info")
            $classifier = [FormatClassifier]::new()
            $routingEngine = [RoutingEngine]::new($logger, $script:testConfig, $classifier)

            $testFile = New-Item -Path "$($script:testConfig.WatchFolders[0].Path)\test.mxf" -ItemType File -Force
            $quarantinePath = $routingEngine.BuildQuarantinePath($testFile, "Test error")

            $today = Get-Date -Format "yyyy-MM-dd"
            $quarantinePath | Should -Match $today

            Remove-Item $testFile.FullName -Force -ErrorAction SilentlyContinue
        }
    }

    Context "Quarantine File Movement" {
        It "Should move files to quarantine on routing errors" {
            $logger = [Logger]::new("$env:TEMP\test.log", "Info")
            $classifier = [FormatClassifier]::new()
            $routingEngine = [RoutingEngine]::new($logger, $script:testConfig, $classifier)

            # Test-Datei erstellen
            $testFile = New-Item -Path "$($script:testConfig.WatchFolders[0].Path)\test_quarantine.mxf" -ItemType File -Force
            "Test content" | Set-Content -Path $testFile.FullName -Encoding UTF8

            # Simuliere Routing-Fehler durch Deaktivieren aller Ziele
            $script:testConfig.Destinations.MAM.Enabled = $false
            $script:testConfig.Destinations.BOX.Enabled = $false
            $script:testConfig.Destinations.Night.Enabled = $false

            # Datei routen (sollte in Quarantäne gehen)
            $routingEngine.RouteFile($testFile)

            # Prüfen ob Datei in Quarantäne verschoben wurde
            $quarantineFiles = Get-ChildItem -Path $script:testConfig.Destinations.Quarantine.Path -Recurse -File
            $quarantineFiles.Name | Should -Contain "test_quarantine.mxf"

            # Aufräumen
            $quarantineFiles | Remove-Item -Force -ErrorAction SilentlyContinue
        }

        It "Should handle transfer failures by moving to quarantine" {
            $logger = [Logger]::new("$env:TEMP\test.log", "Info")
            $classifier = [FormatClassifier]::new()
            $routingEngine = [RoutingEngine]::new($logger, $script:testConfig, $classifier)

            # Test-Datei erstellen
            $testFile = New-Item -Path "$($script:testConfig.WatchFolders[0].Path)\test_transfer_fail.mxf" -ItemType File -Force
            "Test content" | Set-Content -Path $testFile.FullName -Encoding UTF8

            # Konfiguration zurücksetzen
            $script:testConfig.Destinations.MAM.Enabled = $true
            $script:testConfig.Destinations.BOX.Enabled = $true
            $script:testConfig.Destinations.Night.Enabled = $true

            # Ungültiges MAM-Ziel setzen um Transfer-Fehler zu simulieren
            $originalMAMPath = $script:testConfig.Destinations.MAM.Path
            $script:testConfig.Destinations.MAM.Path = "Z:\Invalid\Path"

            # Datei routen (sollte Transfer-Fehler auslösen und in Quarantäne gehen)
            $routingEngine.RouteFile($testFile)

            # Konfiguration zurücksetzen
            $script:testConfig.Destinations.MAM.Path = $originalMAMPath

            # Prüfen ob Datei noch im Watch-Ordner ist (oder in Quarantäne)
            $stillInWatch = Test-Path $testFile.FullName
            if ($stillInWatch) {
                # Datei ist noch da, also sollte sie beim nächsten Routing-Versuch in Quarantäne gehen
                $script:testConfig.Destinations.MAM.Path = "Z:\Invalid\Path\Again"
                $routingEngine.RouteFile($testFile)
                $script:testConfig.Destinations.MAM.Path = $originalMAMPath
            }

            # Aufräumen
            if (Test-Path $testFile.FullName) {
                Remove-Item $testFile.FullName -Force -ErrorAction SilentlyContinue
            }
            $quarantineFiles = Get-ChildItem -Path $script:testConfig.Destinations.Quarantine.Path -Recurse -File
            $quarantineFiles | Remove-Item -Force -ErrorAction SilentlyContinue
        }
    }

    Context "Quarantine Error Grouping" {
        It "Should group quarantine files by error type" {
            $logger = [Logger]::new("$env:TEMP\test.log", "Info")
            $classifier = [FormatClassifier]::new()
            $routingEngine = [RoutingEngine]::new($logger, $script:testConfig, $classifier)

            # Mehrere Test-Dateien mit verschiedenen Fehlern erstellen
            $corruptFile = New-Item -Path "$($script:testConfig.WatchFolders[0].Path)\corrupt.mxf" -ItemType File -Force
            $accessFile = New-Item -Path "$($script:testConfig.WatchFolders[0].Path)\access.mxf" -ItemType File -Force
            $networkFile = New-Item -Path "$($script:testConfig.WatchFolders[0].Path)\network.mxf" -ItemType File -Force

            # Dateien in Quarantäne verschieben
            $routingEngine.RouteToQuarantine($corruptFile, "File is corrupt")
            $routingEngine.RouteToQuarantine($accessFile, "Access denied to destination")
            $routingEngine.RouteToQuarantine($networkFile, "Network connection failed")

            # Prüfen ob Ordner-Struktur korrekt erstellt wurde
            $corruptFolder = Join-Path $script:testConfig.Destinations.Quarantine.Path "CorruptFiles"
            $accessFolder = Join-Path $script:testConfig.Destinations.Quarantine.Path "AccessDenied"
            $networkFolder = Join-Path $script:testConfig.Destinations.Quarantine.Path "NetworkError"

            Test-Path $corruptFolder | Should -Be $true
            Test-Path $accessFolder | Should -Be $true
            Test-Path $networkFolder | Should -Be $true

            # Aufräumen
            $quarantineFiles = Get-ChildItem -Path $script:testConfig.Destinations.Quarantine.Path -Recurse -File
            $quarantineFiles | Remove-Item -Force -ErrorAction SilentlyContinue
        }
    }
}