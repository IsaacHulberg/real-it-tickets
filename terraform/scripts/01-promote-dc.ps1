#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Stage 1: Install AD DS, DNS, DHCP roles and promote to Domain Controller
    Logs to C:\LabBootstrap\logs\stage1.log
.DESCRIPTION
    This script runs via Azure VM Custom Script Extension on the first boot.
    It installs required Windows features, configures static IP, and promotes the server to DC.
    After promotion (which triggers a reboot), Stage 2 is scheduled to run automatically.
#>

param(
    [string]$DomainName = "lab.local",
    [string]$DSRMPassword = "Temppassword123!@#",
    [string]$AdminUsername = "tempadmin",
    [string]$AdminPassword = "Temppassword123!@#"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Setup logging directory
$logDir = "C:\LabBootstrap\logs"
$scriptsDir = "C:\LabBootstrap\scripts"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
if (-not (Test-Path $scriptsDir)) { New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null }

$logFile = Join-Path $logDir "stage1.log"

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    Add-Content -Path $logFile -Value $logMessage
    Write-Host $logMessage
}

function Test-IsDomainController {
    try {
        $forest = Get-ADForest -ErrorAction SilentlyContinue
        return $null -ne $forest
    } catch {
        return $false
    }
}

try {
    Write-Log "=== Stage 1: AD DS / DNS / DHCP Installation and DC Promotion ==="
    Write-Log "Domain Name: $DomainName"
    Write-Log "Timestamp: $(Get-Date)"

    # Check if already a domain controller
    if (Test-IsDomainController) {
        Write-Log "Server is already a Domain Controller. Skipping promotion."
        Write-Log "Stage 1 already completed. Proceeding to finalize."
        exit 0
    }

    # Copy stage 2 scripts from CSE download directory to scripts directory
    # $PSScriptRoot is empty when invoked via -Command, fall back to working directory
    $cseDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
    Write-Log "CSE download directory: $cseDir"
    Write-Log "Copying stage 2 scripts to '$scriptsDir'..."
    foreach ($script in @("02-configure-lab.ps1", "adcreation.ps1")) {
        $src = Join-Path $cseDir $script
        if (Test-Path $src) {
            Copy-Item -Path $src -Destination $scriptsDir -Force
            Write-Log "Copied '$script' to '$scriptsDir'"
        } else {
            Write-Log "ERROR: '$script' not found in '$cseDir' - Stage 2 will fail"
        }
    }

    # Install required Windows Features
    Write-Log "Installing AD DS, DNS, and DHCP features..."
    Install-WindowsFeature -Name AD-Domain-Services, DNS, DHCP -IncludeManagementTools | Out-Null
    Write-Log "Features installed successfully."

    # Schedule Stage 2 BEFORE promotion (Install-ADDSForest triggers an automatic reboot)
    Write-Log "Scheduling Stage 2 script to run after reboot..."

    $taskName = "LabBootstrap-Stage2"
    $taskPath = "\LabBootstrap"

    if (-not (Get-ScheduledTask -TaskPath $taskPath -TaskName $taskName -ErrorAction SilentlyContinue)) {
        $action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
            -Argument "-ExecutionPolicy Bypass -File `"$scriptsDir\02-configure-lab.ps1`" -DomainName '$DomainName' -AdminUsername '$AdminUsername' -AdminPassword '$AdminPassword'"

        $trigger = New-ScheduledTaskTrigger -AtStartup
        $settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -StartWhenAvailable

        # Use the admin credentials for the task (will become domain admin after DC promotion)
        # This is required because SYSTEM doesn't have permissions to create AD objects
        Register-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Action $action -Trigger $trigger -User $AdminUsername -Password $AdminPassword -Settings $settings -RunLevel Highest -Force | Out-Null
        Write-Log "Scheduled Task '$taskName' registered successfully with user '$AdminUsername'."
    } else {
        Write-Log "Scheduled Task '$taskName' already exists."
    }

    # Create DSRM secure password
    $dsrmSecure = ConvertTo-SecureString $DSRMPassword -AsPlainText -Force

    # Promote to Domain Controller
    Write-Log "Promoting server to Domain Controller for domain: $DomainName"
    Install-ADDSForest `
        -DomainName $DomainName `
        -SafeModeAdministratorPassword $dsrmSecure `
        -NoRebootOnCompletion `
        -Force

    Write-Log "DC promotion completed. Scheduling reboot in 10 seconds..."
    shutdown /r /t 10
    Write-Log "Stage 1 finished. Server will reboot momentarily."

} catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    Write-Log "Stack trace: $($_.ScriptStackTrace)"
    exit 1
}
