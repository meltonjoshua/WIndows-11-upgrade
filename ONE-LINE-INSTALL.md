# Windows 11 Silent Upgrade - One-Line Commands

## Copy and paste any of these commands into an elevated PowerShell window (Run as Administrator):

### Basic One-Line Upgrade (Recommended)
```powershell
iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/meltonjoshua/WIndows-11-upgrade/main/Windows11-Silent-Upgrade.ps1'))
```

### Skip Compatibility Checks
```powershell
iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/meltonjoshua/WIndows-11-upgrade/main/Windows11-Silent-Upgrade.ps1')); Start-Windows11Upgrade -SkipChecks
```

### Skip Checks + Prevent Reboot
```powershell
iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/meltonjoshua/WIndows-11-upgrade/main/Windows11-Silent-Upgrade.ps1')); Start-Windows11Upgrade -SkipChecks -NoReboot
```

### For PowerShell 3.0+ (More Secure)
```powershell
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/meltonjoshua/WIndows-11-upgrade/main/Windows11-Silent-Upgrade.ps1' -UseBasicParsing | Invoke-Expression
```

### Enterprise/Custom Logging
```powershell
iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/meltonjoshua/WIndows-11-upgrade/main/Windows11-Silent-Upgrade.ps1')); Start-Windows11Upgrade -LogPath "C:\Windows11Logs"
```

## Instructions:
1. Right-click on PowerShell and select "Run as administrator"
2. Copy one of the commands above
3. Paste into PowerShell and press Enter
4. The script will automatically download and begin the Windows 11 upgrade process

## What These Commands Do:
- Download the latest Windows 11 Silent Upgrade script from GitHub
- Automatically bypass hardware requirements (TPM 2.0, Secure Boot, CPU compatibility)
- Download Windows 11 Installation Assistant from Microsoft
- Perform silent upgrade with comprehensive logging
- Handle errors and provide detailed status information

## Requirements:
- Windows 10 version 1909 or later
- Administrator privileges
- Internet connection
- 4+ GB RAM and 64+ GB free disk space