BeforeAll {
    . "$PSScriptRoot\..\..\src\modules\Logger.ps1"
    . "$PSScriptRoot\..\..\src\modules\FormatClassifier.ps1"
    . "$PSScriptRoot\..\..\src\modules\RoutingEngine.ps1"
    . "$PSScriptRoot\..\..\src\modules\NightBatch.ps1"
    
    $script:TestConfig = @{
        "Destinations" = @{
            "Night" = @{
                "Path" = "$TestDrive\night"
                "ProcessingWindow" = @{
                    "Start" = "00:00"
                    "End" = "23:59"
                }
            }
        }
    }
    
    $script:Logger = [Logger]::new("$TestDrive\test.log", "Debug")
    $script:Classifier = [FormatClassifier]::new($script:Logger)
    $script:RoutingEngine = [RoutingEngine]::new($script:Logger, $script:TestConfig, $script:Classifier)
    $script:NightProcessor = [NightBatchProcessor]::new($script:Logger, $script:TestConfig, $script:Classifier, $script:RoutingEngine)
}

Describe "NightBatch Integration Tests" {
    BeforeEach {
        New-Item -Path "$TestDrive\night" -ItemType Directory -Force
    }
    
    Context "Verarbeitungsfenster" {
        It "Sollte aktuelles Zeitfenster erkennen" {
            $script:NightProcessor.IsProcessingWindow() | Should -Be $true
        }
    }
    
    Context "Dateiverarbeitung" {
        It "Sollte Dateien im Night-Ordner verarbeiten" {
            # Test-Datei erstellen
            "test content" | Out-File "$TestDrive\night\test.txt"
            Start-Sleep -Seconds 2  # Für LastWriteTime
            
            $script:NightProcessor.ProcessNightFolder()
            
            # Log sollte Verarbeitung zeigen
            $logContent = Get-Content "$TestDrive\test.log" -Raw
            $logContent | Should -Match "Nachtverarbeitung"
        }
    }
}