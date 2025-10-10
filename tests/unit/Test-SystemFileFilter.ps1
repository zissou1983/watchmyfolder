BeforeAll {
    . "$PSScriptRoot\..\..\src\modules\Logger.ps1"
    . "$PSScriptRoot\..\..\src\modules\SystemFileFilter.ps1"
    
    $script:TestLogPath = Join-Path $TestDrive "test.log"
    $script:Logger = [Logger]::new($script:TestLogPath, "Debug")
    $script:Filter = [SystemFileFilter]::new($script:Logger)
}

Describe "SystemFileFilter Tests" {
    Context "Kamera-Systemdateien" {
        It "Sollte Sony BIM-Dateien erkennen" {
            $testFile = New-Object System.IO.FileInfo "$TestDrive\test.BIM"
            $script:Filter.IsSystemFile($testFile) | Should -Be $true
        }
        
        It "Sollte Canon CIF-Dateien erkennen" {
            $testFile = New-Object System.IO.FileInfo "$TestDrive\test.CIF"
            $script:Filter.IsSystemFile($testFile) | Should -Be $true
        }
        
        It "Sollte normale MXF-Dateien nicht als System erkennen" {
            $testFile = New-Object System.IO.FileInfo "$TestDrive\video.mxf"
            $script:Filter.IsSystemFile($testFile) | Should -Be $false
        }
    }
    
    Context "OS-Systemdateien" {
        It "Sollte Thumbs.db erkennen" {
            $testFile = New-Object System.IO.FileInfo "$TestDrive\Thumbs.db"
            $script:Filter.IsSystemFile($testFile) | Should -Be $true
        }
        
        It "Sollte .DS_Store erkennen" {
            $testFile = New-Object System.IO.FileInfo "$TestDrive\.DS_Store"
            $script:Filter.IsSystemFile($testFile) | Should -Be $true
        }
    }
}