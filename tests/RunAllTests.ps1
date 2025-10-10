# Test-Runner für alle Tests
param(
    [switch]$Unit,
    [switch]$Integration, 
    [switch]$Performance,
    [switch]$Coverage
)

$ErrorActionPreference = "Stop"

# Pester installieren falls nicht vorhanden
if (-not (Get-Module -ListAvailable -Name Pester)) {
    Write-Host "Installiere Pester..." -ForegroundColor Yellow
    Install-Module -Name Pester -Force -SkipPublisherCheck
}

Import-Module Pester -Force

$testResults = @()
$totalTests = 0
$passedTests = 0
$failedTests = 0

function Run-TestSuite {
    param([string]$Path, [string]$Name)
    
    Write-Host "`n=== $Name Tests ===" -ForegroundColor Cyan
    
    $config = New-PesterConfiguration
    $config.Run.Path = $Path
    $config.Output.Verbosity = 'Detailed'
    $config.TestResult.Enabled = $true
    $config.TestResult.OutputPath = "TestResults-$Name.xml"
    
    if ($Coverage) {
        $config.CodeCoverage.Enabled = $true
        $config.CodeCoverage.Path = "$PSScriptRoot\..\src\modules\*.ps1"
        $config.CodeCoverage.OutputPath = "Coverage-$Name.xml"
    }
    
    $result = Invoke-Pester -Configuration $config
    
    $script:totalTests += $result.TotalCount
    $script:passedTests += $result.PassedCount
    $script:failedTests += $result.FailedCount
    
    $script:testResults += @{
        "Suite" = $Name
        "Total" = $result.TotalCount
        "Passed" = $result.PassedCount
        "Failed" = $result.FailedCount
        "Duration" = $result.Duration
    }
    
    return $result.Result -eq "Passed"
}

Write-Host "Watch Folder Test Suite" -ForegroundColor Green
Write-Host "======================" -ForegroundColor Green

$allPassed = $true

# Unit Tests
if ($Unit -or (-not $Integration -and -not $Performance)) {
    $success = Run-TestSuite "$PSScriptRoot\unit" "Unit"
    $allPassed = $allPassed -and $success
}

# Integration Tests
if ($Integration -or (-not $Unit -and -not $Performance)) {
    $success = Run-TestSuite "$PSScriptRoot\integration" "Integration"
    $allPassed = $allPassed -and $success
}

# Performance Tests
if ($Performance) {
    $success = Run-TestSuite "$PSScriptRoot\performance" "Performance"
    $allPassed = $allPassed -and $success
}

# Zusammenfassung
Write-Host "`n=== Test Zusammenfassung ===" -ForegroundColor Cyan
Write-Host "Gesamt Tests: $totalTests" -ForegroundColor White
Write-Host "Erfolgreich: $passedTests" -ForegroundColor Green
Write-Host "Fehlgeschlagen: $failedTests" -ForegroundColor $(if ($failedTests -gt 0) { "Red" } else { "Green" })

foreach ($result in $testResults) {
    $color = if ($result.Failed -gt 0) { "Red" } else { "Green" }
    Write-Host "$($result.Suite): $($result.Passed)/$($result.Total) ($($result.Duration.TotalSeconds.ToString('F2'))s)" -ForegroundColor $color
}

if ($Coverage) {
    Write-Host "`nCode Coverage Berichte erstellt:" -ForegroundColor Yellow
    Get-ChildItem "Coverage-*.xml" | ForEach-Object { Write-Host "  $($_.Name)" }
}

# Exit Code setzen
if ($allPassed) {
    Write-Host "`n✅ Alle Tests erfolgreich!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n❌ Einige Tests fehlgeschlagen!" -ForegroundColor Red
    exit 1
}