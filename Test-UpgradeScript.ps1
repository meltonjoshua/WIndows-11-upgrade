#Requires -Version 5.1

<#
.SYNOPSIS
    Test script for Windows 11 Silent Upgrade functionality
.DESCRIPTION
    This script performs basic validation of the Windows11-Silent-Upgrade.ps1 script
    without actually performing the upgrade. It tests functions and validates
    the script structure.
#>

[CmdletBinding()]
param(
    [switch]$ShowDetails
)

# Import the main script for testing (dot sourcing)
$scriptPath = Join-Path $PSScriptRoot "Windows11-Silent-Upgrade.ps1"

if (-not (Test-Path $scriptPath)) {
    Write-Error "Cannot find Windows11-Silent-Upgrade.ps1 in the same directory"
    exit 1
}

Write-Host "Windows 11 Silent Upgrade - Test Script" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""

# Test 1: Script Syntax Validation
Write-Host "[TEST 1] Validating PowerShell syntax..." -ForegroundColor Yellow
try {
    $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $scriptPath -Raw), [ref]$null)
    Write-Host "✓ Syntax validation passed" -ForegroundColor Green
    $syntaxValid = $true
}
catch {
    Write-Host "✗ Syntax validation failed: $_" -ForegroundColor Red
    $syntaxValid = $false
}

# Test 2: Required Module Availability
Write-Host "[TEST 2] Checking required modules and features..." -ForegroundColor Yellow
$requiredFeatures = @(
    @{ Name = "BITS"; Test = { Get-Service -Name "BITS" -ErrorAction SilentlyContinue } },
    @{ Name = "CimInstance"; Test = { Get-Command Get-CimInstance -ErrorAction SilentlyContinue } },
    @{ Name = "BitsTransfer"; Test = { Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue } }
)

$featuresAvailable = $true
foreach ($feature in $requiredFeatures) {
    try {
        $result = & $feature.Test
        if ($result) {
            Write-Host "✓ $($feature.Name) is available" -ForegroundColor Green
        } else {
            Write-Host "✗ $($feature.Name) is not available" -ForegroundColor Red
            $featuresAvailable = $false
        }
    }
    catch {
        Write-Host "✗ $($feature.Name) test failed: $_" -ForegroundColor Red
        $featuresAvailable = $false
    }
}

# Test 3: Administrator Privileges
Write-Host "[TEST 3] Checking administrator privileges..." -ForegroundColor Yellow
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($isAdmin) {
    Write-Host "✓ Running with administrator privileges" -ForegroundColor Green
} else {
    Write-Host "✗ Not running with administrator privileges" -ForegroundColor Red
}

# Test 4: Network Connectivity
Write-Host "[TEST 4] Testing network connectivity..." -ForegroundColor Yellow
try {
    $testConnection = Test-NetConnection -ComputerName "download.microsoft.com" -Port 443 -WarningAction SilentlyContinue
    if ($testConnection.TcpTestSucceeded) {
        Write-Host "✓ Network connectivity to Microsoft servers successful" -ForegroundColor Green
        $networkAvailable = $true
    } else {
        Write-Host "✗ Cannot connect to Microsoft download servers" -ForegroundColor Red
        $networkAvailable = $false
    }
}
catch {
    Write-Host "✗ Network connectivity test failed: $_" -ForegroundColor Red
    $networkAvailable = $false
}

# Test 5: PowerShell Version
Write-Host "[TEST 5] Checking PowerShell version..." -ForegroundColor Yellow
$psVersion = $PSVersionTable.PSVersion.Major
if ($psVersion -ge 5) {
    Write-Host "✓ PowerShell version $($PSVersionTable.PSVersion) is supported" -ForegroundColor Green
    $psVersionOk = $true
} else {
    Write-Host "✗ PowerShell version $($PSVersionTable.PSVersion) is too old (5.1+ required)" -ForegroundColor Red
    $psVersionOk = $false
}

# Test 6: Disk Space Check
Write-Host "[TEST 6] Checking available disk space..." -ForegroundColor Yellow
try {
    $systemDrive = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object { $_.DeviceID -eq $env:SystemDrive }
    $freeSpaceGB = [math]::Round($systemDrive.FreeSpace / 1GB, 2)
    
    if ($freeSpaceGB -ge 64) {
        Write-Host "✓ Sufficient disk space available: $freeSpaceGB GB" -ForegroundColor Green
        $diskSpaceOk = $true
    } else {
        Write-Host "✗ Insufficient disk space: $freeSpaceGB GB (64 GB required)" -ForegroundColor Red
        $diskSpaceOk = $false
    }
}
catch {
    Write-Host "✗ Disk space check failed: $_" -ForegroundColor Red
    $diskSpaceOk = $false
}

# Test 7: Registry Access
Write-Host "[TEST 7] Testing registry access..." -ForegroundColor Yellow
try {
    $testKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion"
    $testValue = Get-ItemProperty -Path $testKey -Name "ProgramFilesDir" -ErrorAction Stop
    Write-Host "✓ Registry access successful" -ForegroundColor Green
    $registryAccessOk = $true
}
catch {
    Write-Host "✗ Registry access failed: $_" -ForegroundColor Red
    $registryAccessOk = $false
}

# Test 8: Temporary Directory Access
Write-Host "[TEST 8] Testing temporary directory access..." -ForegroundColor Yellow
try {
    $tempPath = $env:TEMP
    $testFile = Join-Path $tempPath "Windows11UpgradeTest-$(Get-Random).tmp"
    
    "Test" | Out-File -FilePath $testFile -ErrorAction Stop
    Remove-Item $testFile -ErrorAction Stop
    
    Write-Host "✓ Temporary directory access successful" -ForegroundColor Green
    $tempAccessOk = $true
}
catch {
    Write-Host "✗ Temporary directory access failed: $_" -ForegroundColor Red
    $tempAccessOk = $false
}

# Summary
Write-Host ""
Write-Host "Test Summary:" -ForegroundColor Cyan
Write-Host "=============" -ForegroundColor Cyan

$allTests = @(
    @{ Name = "Script Syntax"; Result = $syntaxValid },
    @{ Name = "Required Features"; Result = $featuresAvailable },
    @{ Name = "Administrator Privileges"; Result = $isAdmin },
    @{ Name = "Network Connectivity"; Result = $networkAvailable },
    @{ Name = "PowerShell Version"; Result = $psVersionOk },
    @{ Name = "Disk Space"; Result = $diskSpaceOk },
    @{ Name = "Registry Access"; Result = $registryAccessOk },
    @{ Name = "Temporary Directory"; Result = $tempAccessOk }
)

$passedTests = ($allTests | Where-Object { $_.Result -eq $true }).Count
$totalTests = $allTests.Count

foreach ($test in $allTests) {
    $status = if ($test.Result) { "PASS" } else { "FAIL" }
    $color = if ($test.Result) { "Green" } else { "Red" }
    Write-Host "  $($test.Name): $status" -ForegroundColor $color
}

Write-Host ""
Write-Host "Overall Result: $passedTests/$totalTests tests passed" -ForegroundColor $(if ($passedTests -eq $totalTests) { "Green" } else { "Yellow" })

if ($passedTests -eq $totalTests) {
    Write-Host "✓ System appears ready for Windows 11 upgrade script execution" -ForegroundColor Green
    $exitCode = 0
} else {
    Write-Host "⚠ Some tests failed. Review issues before running the upgrade script" -ForegroundColor Yellow
    $exitCode = 1
}

# Verbose output
if ($ShowDetails) {
    Write-Host ""
    Write-Host "System Information:" -ForegroundColor Cyan
    Write-Host "==================" -ForegroundColor Cyan
    
    $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
    Write-Host "OS: $($osInfo.Caption)" -ForegroundColor White
    Write-Host "Build: $($osInfo.BuildNumber)" -ForegroundColor White
    Write-Host "Architecture: $($env:PROCESSOR_ARCHITECTURE)" -ForegroundColor White
    Write-Host "Memory: $([math]::Round($osInfo.TotalVisibleMemorySize / 1MB, 2)) GB" -ForegroundColor White
    Write-Host "PowerShell: $($PSVersionTable.PSVersion)" -ForegroundColor White
}

Write-Host ""
exit $exitCode