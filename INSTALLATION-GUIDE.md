# Windows 11 Silent Upgrade - Installation and Usage Guide

## One-Line Installation (Recommended)

### Copy and Paste - Run Anywhere
Run this single command in an **elevated PowerShell** (Run as Administrator) to download and execute the Windows 11 upgrade script on any device:

```powershell
iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/meltonjoshua/WIndows-11-upgrade/main/Windows11-Silent-Upgrade.ps1'))
```

**Alternative one-liner with parameters:**
```powershell
# Skip compatibility checks and prevent auto-reboot
iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/meltonjoshua/WIndows-11-upgrade/main/Windows11-Silent-Upgrade.ps1')); Start-Windows11Upgrade -SkipChecks -NoReboot
```

**For PowerShell 3.0+ (more secure):**
```powershell
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/meltonjoshua/WIndows-11-upgrade/main/Windows11-Silent-Upgrade.ps1' -UseBasicParsing | Invoke-Expression
```

> **Note:** These commands will download and immediately execute the Windows 11 upgrade script. Ensure you trust the source and have appropriate backups before running.

## Alternative Installation Methods

## Quick Start

### Method 1: Using the Batch File (Recommended for beginners)
1. Right-click on `RunUpgrade.bat`
2. Select "Run as administrator"
3. Follow the on-screen prompts

### Method 2: Using PowerShell Directly
1. Open PowerShell as Administrator
2. Navigate to the script directory
3. Run: `.\Windows11-Silent-Upgrade.ps1`

## Command Line Options

### Basic Usage
```powershell
# Standard upgrade
.\Windows11-Silent-Upgrade.ps1

# Skip compatibility checks
.\Windows11-Silent-Upgrade.ps1 -SkipChecks

# Prevent automatic reboot
.\Windows11-Silent-Upgrade.ps1 -NoReboot

# Custom log location
.\Windows11-Silent-Upgrade.ps1 -LogPath "C:\CustomLogs"

# Combined options
.\Windows11-Silent-Upgrade.ps1 -SkipChecks -NoReboot -LogPath "C:\Logs"
```

### Advanced Parameters
- `-SkipChecks`: Bypass pre-flight compatibility assessment
- `-NoReboot`: Prevent automatic system reboot after installation
- `-LogPath`: Specify custom directory for log files
- `-DownloadTimeout`: Set download timeout in seconds (default: 1800)
- `-InstallationTimeout`: Set installation timeout in seconds (default: 7200)
- `-ProcessWaitTimeout`: Set process wait timeout in seconds (default: 300)

## System Requirements

### Minimum Requirements
- Windows 10 version 1909 or later
- 4 GB RAM
- 64 GB free disk space
- Administrator privileges
- Internet connection
- PowerShell 5.1 or later

### Supported Systems
- Windows 10 Home, Pro, Enterprise
- x64 and ARM64 architectures
- Systems with or without TPM 2.0
- Legacy BIOS and UEFI systems
- Unsupported CPU generations

## Hardware Bypasses

This script automatically bypasses the following Windows 11 requirements:
- **TPM 2.0**: Disabled through registry modifications
- **Secure Boot**: Validation checks bypassed
- **CPU Compatibility**: Unsupported processors allowed
- **RAM Requirements**: 4GB minimum check bypassed
- **Storage Requirements**: 64GB minimum check bypassed

## Log Files

### Log Locations
- Default: `%TEMP%\Windows11Upgrade\`
- Custom: Specified by `-LogPath` parameter

### Log File Contents
- Detailed installation progress
- Error messages and troubleshooting information
- System compatibility assessment results
- Registry modification logs
- Download and validation status

## Troubleshooting

### Common Issues

#### "Script cannot be loaded because running scripts is disabled"
**Solution**: Run from the batch file or set execution policy:
```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser
```

#### "This script must be run as Administrator"
**Solution**: Right-click PowerShell or batch file and select "Run as administrator"

#### Download fails
**Solutions**:
1. Check internet connection
2. Temporarily disable antivirus/firewall
3. Use different network or VPN
4. Check proxy settings

#### Installation fails with error codes
**Common Error Codes**:
- `0xC1900208`: Compatibility issue - try `-SkipChecks` parameter
- `0x80070570`: File corruption - run `sfc /scannow`
- `0x80070002`: File not found - check disk space and permissions

### Manual Recovery
If the upgrade fails:
1. Check log files for specific error information
2. Run Windows Update Troubleshooter
3. Use System Restore if available
4. Contact support with log files

## Security Considerations

### What the Script Does
- Modifies system registry to bypass hardware checks
- Downloads software from Microsoft servers
- Requires administrator privileges
- Creates detailed system logs

### What the Script Does NOT Do
- Access personal files or data
- Install malware or unwanted software
- Modify system beyond upgrade requirements
- Send data to third parties

### Recommendations
- Run on test systems first
- Create system backup before running
- Review script contents if security is a concern
- Use in controlled enterprise environments

## Enterprise Deployment

### Group Policy Integration
The script can be deployed via:
- Active Directory Group Policy
- Microsoft SCCM/MECM
- PowerShell DSC
- Custom deployment solutions

### Batch Deployment Example
```batch
@echo off
for /f %%i in (computers.txt) do (
    psexec \\%%i -s powershell.exe -ExecutionPolicy Bypass -File "\\server\share\Windows11-Silent-Upgrade.ps1"
)
```

### Monitoring and Reporting
- Centralized log collection recommended
- Monitor exit codes for success/failure
- Track compatibility scores across fleet
- Generate upgrade reports for management

## Support and Updates

### Getting Help
1. Check this documentation
2. Review log files for error details
3. Search Microsoft documentation for error codes
4. Check Windows Update troubleshooting guides

### Script Updates
This script may require updates for:
- New Windows 11 versions
- Changed Microsoft download URLs
- Updated bypass requirements
- Bug fixes and improvements

### Version Information
Current version includes:
- Windows 11 22H2 support
- Enhanced error handling
- Improved compatibility detection
- Network optimization features
- Enterprise deployment features

## Legal and Compliance

### Important Notes
- This script bypasses Microsoft's hardware requirements
- Use at your own risk on unsupported hardware
- Microsoft support may be limited on bypassed systems
- Ensure compliance with organizational policies
- Test thoroughly before production deployment

### Warranty Disclaimer
This script is provided "as-is" without warranties. Users are responsible for:
- Testing in their environment
- Backup and recovery procedures
- Compliance with organizational policies
- Understanding the implications of hardware bypasses