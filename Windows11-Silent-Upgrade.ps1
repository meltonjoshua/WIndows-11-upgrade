#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Windows 11 Silent Upgrade Script - Automated upgrade with hardware requirement bypasses
.DESCRIPTION
    This comprehensive PowerShell script automatically upgrades Windows systems to Windows 11 
    while bypassing various hardware compatibility requirements including TPM 2.0, Secure Boot, 
    and CPU compatibility checks.
.PARAMETER SkipChecks
    Skip pre-flight compatibility checks
.PARAMETER NoReboot
    Prevent automatic reboot after installation
.PARAMETER LogPath
    Custom path for installation logs
.EXAMPLE
    .\Windows11-Silent-Upgrade.ps1
.EXAMPLE
    .\Windows11-Silent-Upgrade.ps1 -SkipChecks -NoReboot -LogPath "C:\Temp\upgrade.log"
#>

[CmdletBinding()]
param(
    [switch]$SkipChecks,
    [switch]$NoReboot,
    [string]$LogPath = "$env:TEMP\Windows11Upgrade",
    [int]$DownloadTimeout = 1800,
    [int]$InstallationTimeout = 7200,
    [int]$ProcessWaitTimeout = 300
)

# Global Variables
$Global:ScriptVersion = "1.0.0"
$Global:LogFile = Join-Path $LogPath "Windows11-Upgrade-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$Global:DownloadPath = Join-Path $env:TEMP "Windows11Assistant"
$Global:AssistantPath = Join-Path $Global:DownloadPath "Windows11InstallationAssistant.exe"
$Global:ProgressPreference = 'SilentlyContinue'

# Registry Bypass Configuration
$Global:BypassPaths = @{
    "HKLM:\SYSTEM\Setup\MoSetup" = @{
        "AllowUpgradesWithUnsupportedTPMOrCPU" = 1
    }
    "HKLM:\SYSTEM\Setup\LabConfig" = @{
        "BypassTPMCheck" = 1
        "BypassSecureBootCheck" = 1
        "BypassRAMCheck" = 1
        "BypassStorageCheck" = 1
        "BypassCPUCheck" = 1
    }
}

# Download URLs
$Global:DownloadUrls = @(
    "https://go.microsoft.com/fwlink/?linkid=2171764",
    "https://download.microsoft.com/download/c/0/6/c06e6c8b-7b3c-4d05-b95b-c5b4b9e4c4b3/Windows11InstallationAssistant.exe"
)

#region Logging Functions

function Initialize-Logging {
    [CmdletBinding()]
    param()
    
    try {
        if (-not (Test-Path $LogPath)) {
            New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
        }
        
        Write-LogMessage "Windows 11 Silent Upgrade Script v$Global:ScriptVersion" -Level "Info"
        Write-LogMessage "Script started at $(Get-Date)" -Level "Info"
        Write-LogMessage "Log file: $Global:LogFile" -Level "Info"
        
        return $true
    }
    catch {
        Write-Error "Failed to initialize logging: $_"
        return $false
    }
}

function Write-LogMessage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [ValidateSet("Info", "Warning", "Error", "Success", "Debug")]
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Console output with colors
    switch ($Level) {
        "Info"    { Write-Host $logEntry -ForegroundColor White }
        "Warning" { Write-Host $logEntry -ForegroundColor Yellow }
        "Error"   { Write-Host $logEntry -ForegroundColor Red }
        "Success" { Write-Host $logEntry -ForegroundColor Green }
        "Debug"   { Write-Host $logEntry -ForegroundColor Gray }
    }
    
    # File output
    try {
        Add-Content -Path $Global:LogFile -Value $logEntry -ErrorAction SilentlyContinue
    }
    catch {
        # Silently continue if logging fails
    }
}

function Show-ProgressIndicator {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Activity,
        
        [int]$PercentComplete = 0,
        
        [string]$Status = "Processing..."
    )
    
    Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete
    Write-LogMessage "$Activity - $Status ($PercentComplete%)" -Level "Debug"
}

#endregion

#region System Compatibility Assessment

function Test-SystemCompatibility {
    [CmdletBinding()]
    param()
    
    Write-LogMessage "Starting system compatibility assessment..." -Level "Info"
    
    $compatibility = @{
        WindowsVersion = $false
        Architecture = $false
        Memory = $false
        Storage = $false
        TPM = $false
        SecureBoot = $false
        CompatibilityScore = 0
    }
    
    try {
        # Check Windows version and build
        $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
        $buildNumber = [int]$osInfo.BuildNumber
        
        Write-LogMessage "Current OS: $($osInfo.Caption) Build $buildNumber" -Level "Info"
        
        if ($buildNumber -ge 19041) {  # Windows 10 2004 or later
            $compatibility.WindowsVersion = $true
            Write-LogMessage "Windows version check: PASSED" -Level "Success"
        } else {
            Write-LogMessage "Windows version check: FAILED (Build $buildNumber < 19041)" -Level "Warning"
        }
        
        # Check system architecture
        $arch = $env:PROCESSOR_ARCHITECTURE
        if ($arch -eq "AMD64" -or $arch -eq "ARM64") {
            $compatibility.Architecture = $true
            Write-LogMessage "Architecture check: PASSED ($arch)" -Level "Success"
        } else {
            Write-LogMessage "Architecture check: FAILED ($arch not supported)" -Level "Error"
        }
        
        # Check RAM (4GB minimum)
        $totalRAM = [math]::Round($osInfo.TotalVisibleMemorySize / 1MB, 2)
        if ($totalRAM -ge 4) {
            $compatibility.Memory = $true
            Write-LogMessage "Memory check: PASSED ($totalRAM GB available)" -Level "Success"
        } else {
            Write-LogMessage "Memory check: FAILED ($totalRAM GB < 4 GB required)" -Level "Warning"
        }
        
        # Check disk space (64GB minimum)
        $systemDrive = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object { $_.DeviceID -eq $env:SystemDrive }
        $freeSpace = [math]::Round($systemDrive.FreeSpace / 1GB, 2)
        
        if ($freeSpace -ge 64) {
            $compatibility.Storage = $true
            Write-LogMessage "Storage check: PASSED ($freeSpace GB free)" -Level "Success"
        } else {
            Write-LogMessage "Storage check: FAILED ($freeSpace GB < 64 GB required)" -Level "Warning"
        }
        
        # Check TPM status
        try {
            $tpm = Get-CimInstance -Namespace "Root\CIMv2\Security\MicrosoftTpm" -ClassName Win32_Tpm -ErrorAction SilentlyContinue
            if ($tpm -and $tpm.SpecVersion -like "2.*") {
                $compatibility.TPM = $true
                Write-LogMessage "TPM check: PASSED (TPM 2.0 detected)" -Level "Success"
            } else {
                Write-LogMessage "TPM check: FAILED (TPM 2.0 not detected - will bypass)" -Level "Warning"
            }
        }
        catch {
            Write-LogMessage "TPM check: FAILED (Cannot detect TPM - will bypass)" -Level "Warning"
        }
        
        # Check Secure Boot
        try {
            $secureBoot = Confirm-SecureBootUEFI -ErrorAction SilentlyContinue
            if ($secureBoot) {
                $compatibility.SecureBoot = $true
                Write-LogMessage "Secure Boot check: PASSED" -Level "Success"
            } else {
                Write-LogMessage "Secure Boot check: FAILED (Not enabled - will bypass)" -Level "Warning"
            }
        }
        catch {
            Write-LogMessage "Secure Boot check: FAILED (Legacy BIOS or not supported - will bypass)" -Level "Warning"
        }
        
        # Calculate compatibility score
        $passed = ($compatibility.Values | Where-Object { $_ -eq $true }).Count
        $compatibility.CompatibilityScore = [math]::Round(($passed / 6) * 100, 0)
        
        Write-LogMessage "Compatibility assessment complete. Score: $($compatibility.CompatibilityScore)%" -Level "Info"
        
        return $compatibility
    }
    catch {
        Write-LogMessage "Error during compatibility assessment: $_" -Level "Error"
        return $compatibility
    }
}

function Test-Prerequisites {
    [CmdletBinding()]
    param()
    
    Write-LogMessage "Checking prerequisites..." -Level "Info"
    
    # Check administrator privileges
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-LogMessage "ERROR: This script must be run as Administrator" -Level "Error"
        return $false
    }
    
    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-LogMessage "ERROR: PowerShell 5.1 or later is required" -Level "Error"
        return $false
    }
    
    # Check network connectivity
    try {
        $testConnection = Test-NetConnection -ComputerName "download.microsoft.com" -Port 443 -WarningAction SilentlyContinue
        if (-not $testConnection.TcpTestSucceeded) {
            Write-LogMessage "WARNING: Cannot connect to Microsoft download servers" -Level "Warning"
        }
    }
    catch {
        Write-LogMessage "WARNING: Network connectivity test failed" -Level "Warning"
    }
    
    Write-LogMessage "Prerequisites check completed" -Level "Success"
    return $true
}

#endregion

#region Registry Modification Engine

function Set-RegistryBypass {
    [CmdletBinding()]
    param()
    
    Write-LogMessage "Configuring registry bypasses for Windows 11 compatibility..." -Level "Info"
    
    try {
        foreach ($regPath in $Global:BypassPaths.Keys) {
            Write-LogMessage "Processing registry path: $regPath" -Level "Debug"
            
            # Ensure the registry path exists
            if (-not (Test-Path $regPath)) {
                Write-LogMessage "Creating registry path: $regPath" -Level "Debug"
                New-Item -Path $regPath -Force | Out-Null
            }
            
            # Set registry values
            foreach ($valueName in $Global:BypassPaths[$regPath].Keys) {
                $valueData = $Global:BypassPaths[$regPath][$valueName]
                
                Write-LogMessage "Setting $regPath\$valueName = $valueData" -Level "Debug"
                Set-ItemProperty -Path $regPath -Name $valueName -Value $valueData -Type DWord -Force
            }
        }
        
        Write-LogMessage "Registry bypasses configured successfully" -Level "Success"
        return $true
    }
    catch {
        Write-LogMessage "Error configuring registry bypasses: $_" -Level "Error"
        return $false
    }
}

function Set-InstallationAssistantBypass {
    [CmdletBinding()]
    param()
    
    Write-LogMessage "Configuring Installation Assistant specific bypasses..." -Level "Info"
    
    try {
        # Additional registry modifications specific to Installation Assistant
        $assistantBypass = @{
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" = @{
                "AllowOSUpgrade" = 1
            }
            "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" = @{
                "DisableWindowsUpdateAccess" = 0
            }
        }
        
        foreach ($regPath in $assistantBypass.Keys) {
            if (-not (Test-Path $regPath)) {
                New-Item -Path $regPath -Force | Out-Null
            }
            
            foreach ($valueName in $assistantBypass[$regPath].Keys) {
                $valueData = $assistantBypass[$regPath][$valueName]
                Set-ItemProperty -Path $regPath -Name $valueName -Value $valueData -Type DWord -Force
                Write-LogMessage "Set $regPath\$valueName = $valueData" -Level "Debug"
            }
        }
        
        Write-LogMessage "Installation Assistant bypasses configured" -Level "Success"
        return $true
    }
    catch {
        Write-LogMessage "Error configuring Installation Assistant bypasses: $_" -Level "Error"
        return $false
    }
}

#endregion

#region Download and File Management

function Download-FileWithProgress {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Url,
        
        [Parameter(Mandatory)]
        [string]$OutputPath,
        
        [int]$TimeoutSeconds = 1800
    )
    
    Write-LogMessage "Downloading file from: $Url" -Level "Info"
    Write-LogMessage "Output path: $OutputPath" -Level "Debug"
    
    try {
        # Ensure output directory exists
        $outputDir = Split-Path $OutputPath -Parent
        if (-not (Test-Path $outputDir)) {
            New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
        }
        
        # Try BITS transfer first (preferred method)
        try {
            Write-LogMessage "Attempting BITS transfer..." -Level "Debug"
            
            $bitsJob = Start-BitsTransfer -Source $Url -Destination $OutputPath -Asynchronous -Description "Windows 11 Assistant Download"
            
            $timeout = [datetime]::Now.AddSeconds($TimeoutSeconds)
            while ($bitsJob.JobState -eq "Transferring" -and [datetime]::Now -lt $timeout) {
                $progress = [math]::Round(($bitsJob.BytesTransferred / $bitsJob.BytesTotal) * 100, 1)
                Show-ProgressIndicator -Activity "Downloading Windows 11 Installation Assistant" -PercentComplete $progress -Status "Downloaded $($bitsJob.BytesTransferred) of $($bitsJob.BytesTotal) bytes"
                Start-Sleep -Seconds 2
            }
            
            Complete-BitsTransfer -BitsJob $bitsJob
            
            if (Test-Path $OutputPath) {
                Write-LogMessage "BITS download completed successfully" -Level "Success"
                return $true
            }
        }
        catch {
            Write-LogMessage "BITS transfer failed: $_" -Level "Warning"
            
            # Clean up failed BITS job
            try {
                Get-BitsTransfer | Where-Object { $_.DisplayName -eq "Windows 11 Assistant Download" } | Remove-BitsTransfer
            }
            catch { }
        }
        
        # Fallback to WebClient
        Write-LogMessage "Attempting WebClient download..." -Level "Debug"
        
        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
        
        # Register progress event
        Register-ObjectEvent -InputObject $webClient -EventName "DownloadProgressChanged" -Action {
            $progress = $Event.SourceEventArgs.ProgressPercentage
            Show-ProgressIndicator -Activity "Downloading Windows 11 Installation Assistant" -PercentComplete $progress -Status "WebClient download in progress"
        } | Out-Null
        
        $webClient.DownloadFileTaskAsync($Url, $OutputPath).Wait($TimeoutSeconds * 1000)
        $webClient.Dispose()
        
        if (Test-Path $OutputPath) {
            Write-LogMessage "WebClient download completed successfully" -Level "Success"
            return $true
        } else {
            Write-LogMessage "Download failed - file not found at destination" -Level "Error"
            return $false
        }
    }
    catch {
        Write-LogMessage "Download error: $_" -Level "Error"
        return $false
    }
    finally {
        Write-Progress -Activity "Downloading Windows 11 Installation Assistant" -Completed
    }
}

function Get-LatestWindowsAssistant {
    [CmdletBinding()]
    param()
    
    Write-LogMessage "Obtaining latest Windows 11 Installation Assistant..." -Level "Info"
    
    foreach ($url in $Global:DownloadUrls) {
        Write-LogMessage "Trying download URL: $url" -Level "Debug"
        
        if (Download-FileWithProgress -Url $url -OutputPath $Global:AssistantPath -TimeoutSeconds $DownloadTimeout) {
            
            # Validate file
            if (Test-Path $Global:AssistantPath) {
                $fileInfo = Get-Item $Global:AssistantPath
                Write-LogMessage "Downloaded file size: $([math]::Round($fileInfo.Length / 1MB, 2)) MB" -Level "Info"
                
                # Basic validation - check if it's a valid PE file
                try {
                    $fileHeader = Get-Content $Global:AssistantPath -Encoding Byte -TotalCount 2
                    if ($fileHeader[0] -eq 0x4D -and $fileHeader[1] -eq 0x5A) {  # MZ header
                        Write-LogMessage "File validation successful - valid executable detected" -Level "Success"
                        return $true
                    } else {
                        Write-LogMessage "File validation failed - not a valid executable" -Level "Error"
                        Remove-Item $Global:AssistantPath -Force -ErrorAction SilentlyContinue
                    }
                }
                catch {
                    Write-LogMessage "Error validating downloaded file: $_" -Level "Error"
                }
            }
        }
    }
    
    Write-LogMessage "Failed to download Windows 11 Installation Assistant from all sources" -Level "Error"
    return $false
}

#endregion

#region Process Management

function Stop-ConflictingProcesses {
    [CmdletBinding()]
    param()
    
    Write-LogMessage "Stopping potentially conflicting processes..." -Level "Info"
    
    # List of processes that commonly interfere with Windows upgrades
    $conflictingProcesses = @(
        "antimalware service executable",
        "avg*",
        "avast*",
        "norton*",
        "mcafee*",
        "kaspersky*",
        "bitdefender*",
        "malwarebytes*",
        "acronis*",
        "carbonite*",
        "crashplan*",
        "backblaze*"
    )
    
    foreach ($processPattern in $conflictingProcesses) {
        try {
            $processes = Get-Process -Name $processPattern -ErrorAction SilentlyContinue
            foreach ($process in $processes) {
                Write-LogMessage "Stopping conflicting process: $($process.Name) (PID: $($process.Id))" -Level "Warning"
                $process.Kill()
                Start-Sleep -Seconds 2
            }
        }
        catch {
            # Continue if process cannot be stopped
        }
    }
    
    # Stop Windows Update service temporarily
    try {
        $wuauserv = Get-Service -Name "wuauserv" -ErrorAction SilentlyContinue
        if ($wuauserv -and $wuauserv.Status -eq "Running") {
            Write-LogMessage "Stopping Windows Update service temporarily" -Level "Info"
            Stop-Service -Name "wuauserv" -Force -ErrorAction SilentlyContinue
        }
    }
    catch {
        Write-LogMessage "Could not stop Windows Update service: $_" -Level "Warning"
    }
    
    Write-LogMessage "Conflicting process cleanup completed" -Level "Success"
}

function Start-UpgradeProcess {
    [CmdletBinding()]
    param()
    
    Write-LogMessage "Starting Windows 11 upgrade process..." -Level "Info"
    
    try {
        # Prepare command line arguments for silent installation
        $arguments = @(
            "/quietinstall",
            "/skipeula",
            "/auto",
            "upgrade",
            "/copylogs",
            $LogPath
        )
        
        $argumentString = $arguments -join " "
        Write-LogMessage "Launching: $Global:AssistantPath $argumentString" -Level "Debug"
        
        # Start the installation process
        $processStartInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processStartInfo.FileName = $Global:AssistantPath
        $processStartInfo.Arguments = $argumentString
        $processStartInfo.UseShellExecute = $false
        $processStartInfo.RedirectStandardOutput = $true
        $processStartInfo.RedirectStandardError = $true
        $processStartInfo.CreateNoWindow = $true
        
        $process = [System.Diagnostics.Process]::Start($processStartInfo)
        
        Write-LogMessage "Installation process started (PID: $($process.Id))" -Level "Success"
        
        return $process
    }
    catch {
        Write-LogMessage "Error starting upgrade process: $_" -Level "Error"
        return $null
    }
}

function Monitor-UpgradeProgress {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Diagnostics.Process]$Process
    )
    
    Write-LogMessage "Monitoring upgrade progress..." -Level "Info"
    
    $timeout = [datetime]::Now.AddSeconds($InstallationTimeout)
    $lastProgressUpdate = [datetime]::Now
    
    while (-not $Process.HasExited -and [datetime]::Now -lt $timeout) {
        try {
            # Check for common Windows 11 upgrade log files to estimate progress
            $setupLogs = @(
                "$env:WINDIR\Panther\setupact.log",
                "$env:WINDIR\Panther\setuperr.log",
                "$LogPath\*upgrade*.log"
            )
            
            $currentTime = [datetime]::Now
            if (($currentTime - $lastProgressUpdate).TotalSeconds -ge 30) {
                
                # Estimate progress based on time elapsed
                $elapsed = ($currentTime - $lastProgressUpdate.AddSeconds(-30)).TotalSeconds
                $estimatedProgress = [math]::Min(90, ($elapsed / $InstallationTimeout) * 100)
                
                Show-ProgressIndicator -Activity "Windows 11 Upgrade in Progress" -PercentComplete $estimatedProgress -Status "Installation proceeding... Please wait."
                
                Write-LogMessage "Upgrade still in progress... Elapsed time: $([math]::Round($elapsed / 60, 1)) minutes" -Level "Info"
                $lastProgressUpdate = $currentTime
            }
            
            Start-Sleep -Seconds 10
        }
        catch {
            Write-LogMessage "Error monitoring progress: $_" -Level "Warning"
        }
    }
    
    if ($Process.HasExited) {
        Write-LogMessage "Upgrade process completed with exit code: $($Process.ExitCode)" -Level "Info"
        return $Process.ExitCode
    } else {
        Write-LogMessage "Upgrade process timed out after $($InstallationTimeout) seconds" -Level "Error"
        try {
            $Process.Kill()
        }
        catch { }
        return -1
    }
}

#endregion

#region Error Handling and Recovery

function Handle-UpgradeErrors {
    [CmdletBinding()]
    param(
        [int]$ExitCode
    )
    
    Write-LogMessage "Handling upgrade exit code: $ExitCode" -Level "Info"
    
    $errorDescriptions = @{
        0 = "Success"
        -1 = "Installation timeout"
        0x80070001 = "Function not implemented"
        0x8007000D = "Invalid data"
        0xC1900101 = "Installation failure"
        0x80070002 = "File not found"
        0xC1900208 = "Compatibility issue detected"
        0xC1900204 = "Migration choice not available"
        0x80070570 = "File or directory is corrupted"
        0x800F0922 = ".NET Framework installation failed"
    }
    
    $hexCode = "0x{0:X8}" -f $ExitCode
    $description = $errorDescriptions[$ExitCode]
    
    if (-not $description) {
        $description = $errorDescriptions[$hexCode]
    }
    
    if (-not $description) {
        $description = "Unknown error"
    }
    
    Write-LogMessage "Exit code $ExitCode ($hexCode): $description" -Level "Info"
    
    # Provide specific recovery suggestions
    switch ($ExitCode) {
        0 {
            Write-LogMessage "Installation completed successfully!" -Level "Success"
            return $true
        }
        0xC1900208 {
            Write-LogMessage "Compatibility issue detected. Attempting additional bypasses..." -Level "Warning"
            # Could implement additional bypass attempts here
            return $false
        }
        0x80070570 {
            Write-LogMessage "Corruption detected. Consider running SFC /scannow and DISM commands" -Level "Warning"
            return $false
        }
        default {
            Write-LogMessage "Installation failed. Check Windows Update logs for more details" -Level "Error"
            return $false
        }
    }
}

function Install-PCHealthCheckApp {
    [CmdletBinding()]
    param()
    
    Write-LogMessage "Installing PC Health Check app for compatibility verification..." -Level "Info"
    
    try {
        $healthCheckUrl = "https://aka.ms/GetPCHealthCheckApp"
        $healthCheckPath = Join-Path $Global:DownloadPath "PCHealthCheckSetup.msi"
        
        if (Download-FileWithProgress -Url $healthCheckUrl -OutputPath $healthCheckPath) {
            Write-LogMessage "Installing PC Health Check app..." -Level "Info"
            
            $installArgs = @("/i", $healthCheckPath, "/quiet", "/norestart")
            $installProcess = Start-Process -FilePath "msiexec.exe" -ArgumentList $installArgs -Wait -PassThru
            
            if ($installProcess.ExitCode -eq 0) {
                Write-LogMessage "PC Health Check app installed successfully" -Level "Success"
                return $true
            } else {
                Write-LogMessage "PC Health Check app installation failed with exit code: $($installProcess.ExitCode)" -Level "Warning"
                return $false
            }
        }
    }
    catch {
        Write-LogMessage "Error installing PC Health Check app: $_" -Level "Warning"
        return $false
    }
}

#endregion

#region Main Execution Flow

function Start-Windows11Upgrade {
    [CmdletBinding()]
    param()
    
    Write-LogMessage "=== Windows 11 Silent Upgrade Script v$Global:ScriptVersion ===" -Level "Info"
    Write-LogMessage "Starting upgrade process..." -Level "Info"
    
    # Phase 1: Pre-Flight Checks
    Write-LogMessage "Phase 1: Pre-Flight Checks" -Level "Info"
    Show-ProgressIndicator -Activity "Windows 11 Upgrade" -PercentComplete 5 -Status "Running pre-flight checks..."
    
    if (-not (Test-Prerequisites)) {
        Write-LogMessage "Prerequisites check failed. Exiting." -Level "Error"
        return $false
    }
    
    if (-not $SkipChecks) {
        $compatibility = Test-SystemCompatibility
        if ($compatibility.CompatibilityScore -lt 50) {
            Write-LogMessage "System compatibility score too low: $($compatibility.CompatibilityScore)%. Consider using -SkipChecks parameter." -Level "Warning"
            if (-not (Read-Host "Continue anyway? (y/N)") -eq "y") {
                return $false
            }
        }
    }
    
    # Phase 2: Environment Preparation
    Write-LogMessage "Phase 2: Environment Preparation" -Level "Info"
    Show-ProgressIndicator -Activity "Windows 11 Upgrade" -PercentComplete 15 -Status "Preparing environment..."
    
    if (-not (Set-RegistryBypass)) {
        Write-LogMessage "Failed to configure registry bypasses" -Level "Error"
        return $false
    }
    
    if (-not (Set-InstallationAssistantBypass)) {
        Write-LogMessage "Failed to configure Installation Assistant bypasses" -Level "Error"
        return $false
    }
    
    Stop-ConflictingProcesses
    
    # Phase 3: Download and Validation
    Write-LogMessage "Phase 3: Download and Validation" -Level "Info"
    Show-ProgressIndicator -Activity "Windows 11 Upgrade" -PercentComplete 25 -Status "Downloading Windows 11 Installation Assistant..."
    
    if (-not (Get-LatestWindowsAssistant)) {
        Write-LogMessage "Failed to download Windows 11 Installation Assistant" -Level "Error"
        return $false
    }
    
    # Phase 4: Installation Execution
    Write-LogMessage "Phase 4: Installation Execution" -Level "Info"
    Show-ProgressIndicator -Activity "Windows 11 Upgrade" -PercentComplete 35 -Status "Starting installation process..."
    
    $upgradeProcess = Start-UpgradeProcess
    if (-not $upgradeProcess) {
        Write-LogMessage "Failed to start upgrade process" -Level "Error"
        return $false
    }
    
    # Monitor the upgrade process
    $exitCode = Monitor-UpgradeProgress -Process $upgradeProcess
    
    # Phase 5: Post-Installation
    Write-LogMessage "Phase 5: Post-Installation" -Level "Info"
    Show-ProgressIndicator -Activity "Windows 11 Upgrade" -PercentComplete 95 -Status "Finalizing installation..."
    
    $success = Handle-UpgradeErrors -ExitCode $exitCode
    
    # Cleanup
    try {
        if (Test-Path $Global:DownloadPath) {
            Remove-Item $Global:DownloadPath -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        # Restart Windows Update service
        Start-Service -Name "wuauserv" -ErrorAction SilentlyContinue
    }
    catch {
        Write-LogMessage "Cleanup error: $_" -Level "Warning"
    }
    
    Show-ProgressIndicator -Activity "Windows 11 Upgrade" -PercentComplete 100 -Status "Completed"
    Write-Progress -Activity "Windows 11 Upgrade" -Completed
    
    if ($success) {
        Write-LogMessage "Windows 11 upgrade completed successfully!" -Level "Success"
        
        if (-not $NoReboot) {
            Write-LogMessage "System will reboot in 60 seconds. Use Ctrl+C to cancel." -Level "Warning"
            Start-Sleep -Seconds 60
            Restart-Computer -Force
        }
    } else {
        Write-LogMessage "Windows 11 upgrade failed. Check log file for details: $Global:LogFile" -Level "Error"
    }
    
    return $success
}

#endregion

# Script Entry Point
try {
    # Initialize logging
    if (-not (Initialize-Logging)) {
        Write-Error "Failed to initialize logging system"
        exit 1
    }
    
    # Start the upgrade process
    $result = Start-Windows11Upgrade
    
    Write-LogMessage "Script execution completed. Result: $result" -Level "Info"
    exit ($result ? 0 : 1)
}
catch {
    Write-LogMessage "Fatal error: $_" -Level "Error"
    Write-LogMessage "Stack trace: $($_.ScriptStackTrace)" -Level "Debug"
    exit 1
}
finally {
    Write-LogMessage "Script ended at $(Get-Date)" -Level "Info"
}