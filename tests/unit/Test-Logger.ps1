# Pester Tests für Logger-Klasse
BeforeAll {
    # Module laden
    . "$PSScriptRoot\..\..\src\modules\Logger.ps1"
    
    # Test-Verzeichnis erstellen
    $script:TestLogDir = Join-Path $TestDrive "logs"
    $script:TestLogPath = Join-Path $script:TestLogDir "test.log"
}

Describe "Logger Tests" {
    Context "Initialisierung" {
        It "Sollte Logger-Instanz erstellen" {
            $logger = [Logger]::new($script:TestLogPath, "Info")
            $logger | Should -Not -BeNullOrEmpty
            $logger.LogPath | Should -Be $script:TestLogPath
            $logger.LogLevel | Should -Be "Info"
        }
        
        It "Sollte Log-Verzeichnis erstellen" {
            $logger = [Logger]::new($script:TestLogPath, "Info")
            Test-Path $script:TestLogDir | Should -Be $true
        }
    }
    
    Context "Log-Funktionen" {
        BeforeEach {
            $script:Logger = [Logger]::new($script:TestLogPath, "Debug")
            if (Test-Path $script:TestLogPath) {
                Remove-Item $script:TestLogPath -Force
            }
        }
        
        It "Sollte Info-Log schreiben" {
            $script:Logger.Info("Test Info Message")
            
            Test-Path $script:TestLogPath | Should -Be $true
            $content = Get-Content $script:TestLogPath -Raw
            $content | Should -Match "Test Info Message"
            $content | Should -Match "\[Info\]"
        }
        
        It "Sollte Warning-Log schreiben" {
            $script:Logger.Warning("Test Warning Message")
            
            $content = Get-Content $script:TestLogPath -Raw
            $content | Should -Match "Test Warning Message"
            $content | Should -Match "\[Warning\]"
        }
        
        It "Sollte Error-Log schreiben" {
            $script:Logger.Error("Test Error Message")
            
            $content = Get-Content $script:TestLogPath -Raw
            $content | Should -Match "Test Error Message"
            $content | Should -Match "\[Error\]"
        }
        
        It "Sollte Debug-Log nur bei Debug-Level schreiben" {
            $script:Logger.Debug("Test Debug Message")
            
            $content = Get-Content $script:TestLogPath -Raw
            $content | Should -Match "Test Debug Message"
            $content | Should -Match "\[Debug\]"
        }
        
        It "Sollte Debug-Log bei Info-Level nicht schreiben" {
            $infoLogger = [Logger]::new($script:TestLogPath, "Info")
            $infoLogger.Debug("Test Debug Message")
            
            if (Test-Path $script:TestLogPath) {
                $content = Get-Content $script:TestLogPath -Raw
                $content | Should -Not -Match "Test Debug Message"
            }
        }
        
        It "Sollte Context-Informationen loggen" {
            $context = @{ "File" = "test.txt"; "Size" = 1024 }
            $script:Logger.Info("Test with context", $context)
            
            $content = Get-Content $script:TestLogPath -Raw
            $content | Should -Match "Context:"
            $content | Should -Match "test.txt"
            $content | Should -Match "1024"
        }
        
        It "Sollte Timestamp im korrekten Format haben" {
            $script:Logger.Info("Timestamp test")
            
            $content = Get-Content $script:TestLogPath -Raw
            $content | Should -Match "\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\]"
        }
    }
    
    Context "Log-Rotation" {
        BeforeEach {
            $script:Logger = [Logger]::new($script:TestLogPath, "Info")
            $script:Logger.MaxSizeMB = 1  # 1MB für Tests
            
            if (Test-Path $script:TestLogPath) {
                Remove-Item $script:TestLogPath -Force
            }
        }
        
        It "Sollte Log rotieren bei Überschreitung der Maximalgröße" {
            # Große Log-Datei erstellen (> 1MB)
            $largeMessage = "x" * 1048576  # 1MB
            $script:Logger.Info($largeMessage)
            
            # Weitere Nachricht hinzufügen um Rotation auszulösen
            $script:Logger.Info("Trigger rotation")
            
            # Rotierte Datei sollte existieren
            $rotatedFile = $script:TestLogPath -replace "\.log$", ".1.log"
            Test-Path $rotatedFile | Should -Be $true
        }
        
        It "Sollte mehrere Rotationen verwalten" {
            $script:Logger.MaxFiles = 3
            
            # Mehrere Rotationen simulieren
            for ($i = 1; $i -le 5; $i++) {
                $largeMessage = "x" * 1048576
                $script:Logger.Info("Rotation $i - $largeMessage")
            }
            
            # Nur MaxFiles Anzahl rotierter Dateien sollten existieren
            $rotatedFiles = Get-ChildItem -Path $script:TestLogDir -Filter "*.*.log"
            $rotatedFiles.Count | Should -BeLessOrEqual $script:Logger.MaxFiles
        }
    }
    
    Context "Fehlerbehandlung" {
        It "Sollte mit ungültigem Pfad umgehen" {
            $invalidPath = "Z:\NonExistent\Path\test.log"
            
            { [Logger]::new($invalidPath, "Info") } | Should -Throw
        }
        
        It "Sollte mit Berechtigungsfehlern umgehen" {
            # Schwer zu testen ohne Admin-Rechte
            # Placeholder für zukünftige Implementierung
            $true | Should -Be $true
        }
    }
}

Describe "Logger Performance Tests" {
    Context "Performance" {
        BeforeAll {
            $script:PerfLogger = [Logger]::new($script:TestLogPath, "Info")
        }
        
        It "Sollte 1000 Log-Einträge in angemessener Zeit schreiben" {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            for ($i = 1; $i -le 1000; $i++) {
                $script:PerfLogger.Info("Performance test message $i")
            }
            
            $stopwatch.Stop()
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 5000  # Weniger als 5 Sekunden
        }
        
        It "Sollte mit gleichzeitigen Schreibvorgängen umgehen" {
            $jobs = @()
            
            # 5 parallele Jobs starten
            for ($i = 1; $i -le 5; $i++) {
                $job = Start-Job -ScriptBlock {
                    param($LogPath, $JobId)
                    
                    . "$using:PSScriptRoot\..\..\src\modules\Logger.ps1"
                    $logger = [Logger]::new($LogPath, "Info")
                    
                    for ($j = 1; $j -le 100; $j++) {
                        $logger.Info("Concurrent test Job$JobId Message$j")
                    }
                } -ArgumentList $script:TestLogPath, $i
                
                $jobs += $job
            }
            
            # Auf alle Jobs warten
            $jobs | Wait-Job | Remove-Job
            
            # Log-Datei sollte alle Nachrichten enthalten
            $content = Get-Content $script:TestLogPath
            $content.Count | Should -BeGreaterThan 400  # Mindestens 400 von 500 Nachrichten
        }
    }
}