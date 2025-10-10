BeforeAll {
    . "$PSScriptRoot\..\..\src\modules\Logger.ps1"
    . "$PSScriptRoot\..\..\src\modules\FormatClassifier.ps1"
    . "$PSScriptRoot\..\..\src\modules\RoutingEngine.ps1"
    
    $script:TestConfig = @{
        "WatchFolders" = @(@{ "Path" = "$TestDrive\watch" })
        "Destinations" = @{
            "MAM" = @{ "Path" = "$TestDrive\mam"; "Enabled" = $true }
            "BOX" = @{ "Path" = "$TestDrive\box"; "Enabled" = $true }
        }
    }
    
    $script:Logger = [Logger]::new("$TestDrive\perf.log", "Info")
    $script:Classifier = [FormatClassifier]::new($script:Logger)
    $script:RoutingEngine = [RoutingEngine]::new($script:Logger, $script:TestConfig, $script:Classifier)
}

Describe "Performance Tests" {
    BeforeEach {
        New-Item "$TestDrive\watch" -ItemType Directory -Force
        New-Item "$TestDrive\mam" -ItemType Directory -Force
        New-Item "$TestDrive\box" -ItemType Directory -Force
    }
    
    Context "Große Dateien" {
        It "Sollte 100MB Datei in angemessener Zeit verarbeiten" {
            # 100MB Test-Datei erstellen
            $largeFile = "$TestDrive\watch\large.mxf"
            $buffer = New-Object byte[] (1MB)
            $stream = [System.IO.File]::Create($largeFile)
            
            try {
                for ($i = 0; $i -lt 100; $i++) {
                    $stream.Write($buffer, 0, $buffer.Length)
                }
            } finally {
                $stream.Close()
            }
            
            # Transfer-Zeit messen
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            $file = Get-Item $largeFile
            $script:RoutingEngine.RouteFile($file)
            
            $stopwatch.Stop()
            
            # Sollte weniger als 30 Sekunden dauern
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 30000
            Test-Path "$TestDrive\mam\large.mxf" | Should -Be $true
        }
    }
    
    Context "Viele kleine Dateien" {
        It "Sollte 1000 kleine Dateien schnell verarbeiten" {
            # 1000 kleine Dateien erstellen
            for ($i = 1; $i -le 1000; $i++) {
                "content $i" | Out-File "$TestDrive\watch\file$i.txt"
            }
            
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            # Alle Dateien verarbeiten
            Get-ChildItem "$TestDrive\watch" -File | ForEach-Object {
                $script:RoutingEngine.RouteFile($_)
            }
            
            $stopwatch.Stop()
            
            # Sollte weniger als 60 Sekunden dauern
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 60000
            
            # Alle Dateien sollten verarbeitet sein
            (Get-ChildItem "$TestDrive\box" -File).Count | Should -Be 1000
        }
    }
    
    Context "Klassifizierung Performance" {
        It "Sollte 10000 Klassifizierungen schnell durchführen" {
            $testFile = New-Object System.IO.FileInfo "$TestDrive\test.mxf"
            New-Item $testFile.FullName -ItemType File -Force
            
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            for ($i = 1; $i -le 10000; $i++) {
                $result = $script:Classifier.ClassifyFile($testFile)
            }
            
            $stopwatch.Stop()
            
            # Sollte weniger als 10 Sekunden dauern
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 10000
        }
    }
}