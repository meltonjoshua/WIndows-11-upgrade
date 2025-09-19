# Windows 11 Silent Upgrade Configuration
# This file contains configuration parameters for the upgrade script

# Download and timeout settings
$Config = @{
    # Download timeout in seconds (default: 30 minutes)
    DownloadTimeout = 1800
    
    # Installation timeout in seconds (default: 2 hours)
    InstallationTimeout = 7200
    
    # Process wait timeout in seconds (default: 5 minutes)
    ProcessWaitTimeout = 300
    
    # Maximum retry attempts for failed operations
    MaxRetryAttempts = 3
    
    # Log retention in days
    LogRetentionDays = 30
    
    # Enable verbose logging
    VerboseLogging = $true
    
    # Automatically install PC Health Check app
    InstallPCHealthCheck = $true
    
    # Create system restore point before upgrade
    CreateRestorePoint = $true
    
    # Backup registry before modifications
    BackupRegistry = $true
}

# Advanced bypass settings
$BypassConfig = @{
    # Enable all hardware requirement bypasses
    EnableAllBypasses = $true
    
    # Specific bypass toggles
    BypassTPM = $true
    BypassSecureBoot = $true
    BypassRAMCheck = $true
    BypassStorageCheck = $true
    BypassCPUCheck = $true
    
    # Skip compatibility checks entirely
    SkipCompatibilityChecks = $false
}

# Network configuration
$NetworkConfig = @{
    # Use BITS for downloads when available
    PreferBITS = $true
    
    # Bandwidth throttling for BITS (bytes per second, 0 = unlimited)
    BITSThrottling = 0
    
    # Alternative download URLs (in order of preference)
    DownloadUrls = @(
        "https://go.microsoft.com/fwlink/?linkid=2171764",
        "https://download.microsoft.com/download/c/0/6/c06e6c8b-7b3c-4d05-b95b-c5b4b9e4c4b3/Windows11InstallationAssistant.exe"
    )
    
    # Proxy settings (leave empty for system default)
    ProxyServer = ""
    ProxyPort = ""
    ProxyCredentials = $null
}

# Export configuration for use by main script
Export-ModuleMember -Variable Config, BypassConfig, NetworkConfig