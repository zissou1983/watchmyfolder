BeforeAll {
    . "$PSScriptRoot\..\..\src\modules\Logger.ps1"
    . "$PSScriptRoot\..\..\src\modules\SystemFileFilter.ps1"
    . "$PSScriptRoot\..\..\src\modules\FormatClassifier.ps1"
    . "$PSScriptRoot\..\..\src\modules\WatchEngine.ps1"
    . "$PSScriptRoot\..\..\src\modules\RoutingEngine.ps1"
    
    $script:TestConfig = @{
        "WatchFolders" = @(@{ "Path" = "$TestDrive\watch"; "Enabled" = $true; "GracePeriod" = 2 })
        "Destinations" = @{
            "MAM" = @{ "Path" = "$TestDrive\mam"; "Enabled" = $true }
            "BOX" = @{ "Path" = "$TestDrive\box"; "Enabled" = $true; "SanitizeFilenames" = $true }
            "Night" = @{ "Path" = "$TestDrive\night" }
        }
        "Performance" = @{ "ProcessingInterval" = 1; "QueueMaxSize" = 100 }
    }
    
    $script:Logger = [Logger]::new("$TestDrive\test.log", "Debug")
}

Describe "Watch Folder Integration Tests" {
    BeforeEach {
        # Verzeichnisse erstellen
        @("watch", "mam", "box", "night") | ForEach-Object {
            New-Item "$TestDrive\$_" -ItemType Directory -Force
        }
        
        # Komponenten initialisieren
        $script:SystemFilter = [SystemFileFilter]::new($script:Logger)
        $script:Classifier = [FormatClassifier]::new($script:Logger)
        $script:RoutingEngine = [RoutingEngine]::new($script:Logger, $script:TestConfig, $script:Classifier)
        $script:WatchEngine = [WatchEngine]::new($script:Logger, $script:TestConfig)
    }
    
    Context "End-to-End Workflow" {
        It "Sollte MXF-Datei zu MAM routen" {
            # Test-MXF erstellen
            $mxfFile = "$TestDrive\watch\test.mxf"
            [byte[]]$mxfHeader = @(0x06, 0x0E, 0x2B, 0x34) + @(0x00) * 100
            [System.IO.File]::WriteAllBytes($mxfFile, $mxfHeader)
            
            # Datei verarbeiten
            $file = Get-Item $mxfFile
            if (-not $script:SystemFilter.IsSystemFile($file)) {
                $script:RoutingEngine.RouteFile($file)
            }
            
            # Prüfen ob in MAM gelandet
            Test-Path "$TestDrive\mam\test.mxf" | Should -Be $true
            Test-Path $mxfFile | Should -Be $false
        }
        
        It "Sollte PDF-Datei zu BOX routen" {
            # Test-PDF erstellen
            $pdfFile = "$TestDrive\watch\document.pdf"
            "PDF content" | Out-File $pdfFile
            
            # Datei verarbeiten
            $file = Get-Item $pdfFile
            $script:RoutingEngine.RouteFile($file)
            
            # Prüfen ob in BOX gelandet
            Test-Path "$TestDrive\box\document.pdf" | Should -Be $true
            Test-Path $pdfFile | Should -Be $false
        }
        
        It "Sollte System-Dateien ignorieren" {
            # System-Datei erstellen
            $sysFile = "$TestDrive\watch\Thumbs.db"
            "system file" | Out-File $sysFile
            
            # Datei prüfen
            $file = Get-Item $sysFile
            $script:SystemFilter.IsSystemFile($file) | Should -Be $true
            
            # Datei sollte nicht verarbeitet werden
            Test-Path $sysFile | Should -Be $true
        }
        
        It "Sollte unbekannte Dateien zu Night routen" {
            # Unbekannte Datei erstellen
            $unknownFile = "$TestDrive\watch\unknown.xyz"
            "unknown content" | Out-File $unknownFile
            
            # Datei verarbeiten
            $file = Get-Item $unknownFile
            $script:RoutingEngine.RouteFile($file)
            
            # Prüfen ob in Night gelandet
            Test-Path "$TestDrive\night\*\unknown.xyz" | Should -Be $true
            Test-Path $unknownFile | Should -Be $false
        }
    }
    
    Context "Fehlerbehandlung" {
        It "Sollte mit gesperrten Dateien umgehen" {
            $lockedFile = "$TestDrive\watch\locked.txt"
            "content" | Out-File $lockedFile
            
            # Datei sperren
            $stream = [System.IO.File]::Open($lockedFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::None)
            
            try {
                $file = Get-Item $lockedFile
                $isLocked = $script:WatchEngine.IsFileLocked($file)
                $isLocked | Should -Be $true
            } finally {
                $stream.Close()
            }
        }
    }
}