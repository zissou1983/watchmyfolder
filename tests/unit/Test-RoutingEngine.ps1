BeforeAll {
    . "$PSScriptRoot\..\..\src\modules\Logger.ps1"
    . "$PSScriptRoot\..\..\src\modules\FormatClassifier.ps1"
    . "$PSScriptRoot\..\..\src\modules\RoutingEngine.ps1"
    
    $script:TestConfig = @{
        "WatchFolders" = @(@{ "Path" = "$TestDrive\incoming" })
        "Destinations" = @{
            "MAM" = @{ "Path" = "$TestDrive\mam"; "Enabled" = $true; "PreserveFolderStructure" = $true }
            "BOX" = @{ "Path" = "$TestDrive\box"; "Enabled" = $true; "SanitizeFilenames" = $true }
            "Night" = @{ "Path" = "$TestDrive\night" }
        }
    }
    
    $script:Logger = [Logger]::new("$TestDrive\test.log", "Debug")
    $script:Classifier = [FormatClassifier]::new($script:Logger)
    $script:RoutingEngine = [RoutingEngine]::new($script:Logger, $script:TestConfig, $script:Classifier)
}

Describe "RoutingEngine Tests" {
    BeforeEach {
        New-Item "$TestDrive\mam" -ItemType Directory -Force
        New-Item "$TestDrive\box" -ItemType Directory -Force
        New-Item "$TestDrive\night" -ItemType Directory -Force
        New-Item "$TestDrive\incoming" -ItemType Directory -Force
    }
    
    Context "BOX Pfad-Sanitization" {
        It "Sollte Prozentzeichen ersetzen" {
            $result = $script:RoutingEngine.SanitizePathForBOX("file%20name.pdf")
            $result | Should -Be "file_20name.pdf"
        }
        
        It "Sollte mehrere Sonderzeichen ersetzen" {
            $result = $script:RoutingEngine.SanitizePathForBOX("file@#$%^&().pdf")
            $result | Should -Be "file_.pdf"
        }
        
        It "Sollte mehrfache Unterstriche reduzieren" {
            $result = $script:RoutingEngine.SanitizePathForBOX("file___name.pdf")
            $result | Should -Be "file_name.pdf"
        }
    }
    
    Context "Pfad-Konstruktion" {
        It "Sollte MAM-Pfad mit Struktur erstellen" {
            $testFile = New-Object System.IO.FileInfo "$TestDrive\incoming\subfolder\video.mxf"
            New-Item $testFile.DirectoryName -ItemType Directory -Force
            New-Item $testFile.FullName -ItemType File -Force
            
            $result = $script:RoutingEngine.BuildMAMPath($testFile)
            $result | Should -Match "mam.*subfolder.*video.mxf"
        }
        
        It "Sollte BOX-Pfad mit Sanitization erstellen" {
            $testFile = New-Object System.IO.FileInfo "$TestDrive\incoming\file%20name.pdf"
            New-Item $testFile.FullName -ItemType File -Force
            
            $result = $script:RoutingEngine.BuildBOXPath($testFile)
            $result | Should -Match "file_20name.pdf"
        }
    }
    
    Context "Namenskonflikt-Auflösung" {
        It "Sollte Namenskonflikte auflösen" {
            # Existierende Datei erstellen
            New-Item "$TestDrive\mam\existing.mxf" -ItemType File -Force
            
            $result = $script:RoutingEngine.ResolveNameConflict("$TestDrive\mam\existing.mxf")
            $result | Should -Match "existing_\d+\.mxf"
        }
    }
}