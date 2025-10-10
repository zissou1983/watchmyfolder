BeforeAll {
    . "$PSScriptRoot\..\..\src\modules\Logger.ps1"
    . "$PSScriptRoot\..\..\src\modules\FormatClassifier.ps1"
    
    $script:Logger = [Logger]::new("$TestDrive\test.log", "Debug")
    $script:Classifier = [FormatClassifier]::new($script:Logger)
}

Describe "FormatClassifier Tests" {
    Context "MXF-Dateien" {
        It "Sollte MXF-Extension erkennen" {
            $testFile = New-Object System.IO.FileInfo "$TestDrive\test.mxf"
            New-Item $testFile.FullName -ItemType File -Force
            
            $result = $script:Classifier.ClassifyFile($testFile)
            $result | Should -Be "MAM"
        }
        
        It "Sollte MXF Magic Number validieren" {
            $testFile = New-Object System.IO.FileInfo "$TestDrive\valid.mxf"
            # MXF Magic Number: 060E2B34
            [byte[]]$mxfHeader = @(0x06, 0x0E, 0x2B, 0x34, 0x00, 0x00, 0x00, 0x00)
            [System.IO.File]::WriteAllBytes($testFile.FullName, $mxfHeader)
            
            $script:Classifier.IsMXFFile($testFile) | Should -Be $true
        }
    }
    
    Context "Video/Audio-Dateien" {
        It "Sollte MOV-Dateien als MAM klassifizieren" {
            $testFile = New-Object System.IO.FileInfo "$TestDrive\video.mov"
            New-Item $testFile.FullName -ItemType File -Force
            
            $result = $script:Classifier.ClassifyFile($testFile)
            $result | Should -Be "MAM"
        }
        
        It "Sollte WAV-Dateien als MAM klassifizieren" {
            $testFile = New-Object System.IO.FileInfo "$TestDrive\audio.wav"
            New-Item $testFile.FullName -ItemType File -Force
            
            $result = $script:Classifier.ClassifyFile($testFile)
            $result | Should -Be "MAM"
        }
    }
    
    Context "Dokumente" {
        It "Sollte PDF-Dateien als BOX klassifizieren" {
            $testFile = New-Object System.IO.FileInfo "$TestDrive\document.pdf"
            New-Item $testFile.FullName -ItemType File -Force
            
            $result = $script:Classifier.ClassifyFile($testFile)
            $result | Should -Be "BOX"
        }
    }
    
    Context "Unbekannte Dateien" {
        It "Sollte unbekannte Extensions als UNKNOWN klassifizieren" {
            $testFile = New-Object System.IO.FileInfo "$TestDrive\unknown.xyz"
            New-Item $testFile.FullName -ItemType File -Force
            
            $result = $script:Classifier.ClassifyFile($testFile)
            $result | Should -Be "UNKNOWN"
        }
    }
}