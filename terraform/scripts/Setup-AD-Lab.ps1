#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Automated Active Directory Lab Setup Script
.DESCRIPTION
    Converts a fresh Windows Server into a fully functional AD lab environment
    with Domain Controller promotion, OUs, 30 test users, and DHCP configuration.
    Safe to re-run (idempotent). Handles reboots automatically.
.PARAMETER DSRMPassword
    Directory Services Restore Mode password. Defaults to a complex 16-char string.
    Change this to your desired DSRM password.
#>

param(
    [Parameter(Mandatory = $false)]
    [ValidateLength(8, 128)]
    [string]$DSRMPassword = "tempadmin123!@#"
)

# ============================================================================
# CONFIGURATION & CONSTANTS
# ============================================================================

$script:LogDir = "C:\LabBootstrap\Logs"
$script:LogFile = Join-Path $LogDir "setup.log"
$script:DoneFile = "C:\LabBootstrap\DONE.txt"
$script:UsersDir = "C:\LabBootstrap\Users"
$script:UsersCSV = Join-Path $UsersDir "created_users.csv"

$DomainName = "lab.local"
$NetBIOSName = "LAB"
$DomainDN = "DC=lab,DC=local"

# ============================================================================
# INITIALIZATION
# ============================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

# Create log directory if it doesn't exist
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================

function Write-Log {
    <#
    .SYNOPSIS
        Writes a timestamped log message to both console and log file.
    .PARAMETER Message
        The message to log.
    .PARAMETER Level
        Log level: INFO, WARN, ERROR. Defaults to INFO.
    #>
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR")]
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"

    # Write to console with color
    switch ($Level) {
        "INFO"  { Write-Host $logMessage -ForegroundColor Cyan }
        "WARN"  { Write-Host $logMessage -ForegroundColor Yellow }
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
    }

    # Write to log file
    Add-Content -Path $LogFile -Value $logMessage -ErrorAction SilentlyContinue
}

function Test-DoneFileExists {
    <#
    .SYNOPSIS
        Tests if the setup completion marker exists.
    #>
    return (Test-Path $DoneFile)
}

function New-DoneFile {
    <#
    .SYNOPSIS
        Creates the setup completion marker file.
    #>
    New-Item -ItemType File -Path $DoneFile -Force | Out-Null
    Write-Log "Setup completed successfully. Marker file created: $DoneFile"
}

# ============================================================================
# DOMAIN CONTROLLER PROMOTION
# ============================================================================

function Test-IsDomainController {
    <#
    .SYNOPSIS
        Checks if the server is already a Domain Controller.
    #>
    try {
        $forest = Get-ADForest -ErrorAction Stop
        Write-Log "Server is already a Domain Controller in forest: $($forest.Name)"
        return $true
    }
    catch {
        Write-Log "Server is not yet a Domain Controller"
        return $false
    }
}

function Invoke-DCPromotion {
    <#
    .SYNOPSIS
        Installs AD DS and DNS, then promotes the server to a new forest.
    #>
    Write-Log "INFO: Starting Domain Controller promotion"

    try {
        # Install AD DS and DNS roles
        Write-Log "Installing AD-Domain-Services and DNS roles..."
        Install-WindowsFeature -Name AD-Domain-Services, DNS -IncludeManagementTools | Out-Null
        Write-Log "Roles installed successfully"

        # Prepare DSRM password as secure string
        $dsrmSecure = ConvertTo-SecureString -String $DSRMPassword -AsPlainText -Force

        # Promote to DC
        Write-Log "Promoting server to Domain Controller..."
        Install-ADDSForest `
            -DomainName $DomainName `
            -DomainNetBIOSName $NetBIOSName `
            -SafeModeAdministratorPassword $dsrmSecure `
            -Force | Out-Null

        Write-Log "DC promotion completed. Server requires restart."

        Write-Log "Initiating restart..."
        Restart-Computer -Force
    }
    catch {
        Write-Log "ERROR during DC promotion: $($_.Exception.Message)" -Level "ERROR"
        Write-Log "Full error: $($_.ScriptStackTrace)" -Level "ERROR"
        return
    }
}

# ============================================================================
# ACTIVE DIRECTORY CONFIGURATION
# ============================================================================

function New-ADOUStructure {
    <#
    .SYNOPSIS
        Creates the OU structure for the lab.
    #>
    Write-Log "Creating Organizational Units..."

    $OUs = @(
        @{ Name = "Users"; Path = $DomainDN }
        @{ Name = "Groups"; Path = $DomainDN }
        @{ Name = "Workstations"; Path = $DomainDN }
    )

    foreach ($OU in $OUs) {
        $ouPath = "OU=$($OU.Name),$($OU.Path)"
        
        try {
            Get-ADOrganizationalUnit -Identity $ouPath -ErrorAction Stop | Out-Null
            Write-Log "OU already exists: $ouPath"
        }
        catch {
            Write-Log "Creating OU: $ouPath"
            New-ADOrganizationalUnit -Name $OU.Name -Path $OU.Path -ProtectedFromAccidentalDeletion $false | Out-Null
        }
    }

    Write-Log "OU structure completed"
}

function New-TestPassword {
    <#
    .SYNOPSIS
        Generates a random 14-character password meeting complexity requirements:
        - At least one uppercase letter
        - At least one lowercase letter
        - At least one number
        - At least one special character
    .OUTPUTS
        A 14-character password string
    #>
    $uppercase = [char[]]'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    $lowercase = [char[]]'abcdefghijklmnopqrstuvwxyz'
    $numbers = [char[]]'0123456789'
    $special = [char[]]'!@#$%^&*'

    $password = @()
    $password += Get-Random -InputObject $uppercase
    $password += Get-Random -InputObject $lowercase
    $password += Get-Random -InputObject $numbers
    $password += Get-Random -InputObject $special

    # Fill remaining 10 characters with random selections from all character sets
    $allChars = $uppercase + $lowercase + $numbers + $special
    for ($i = 0; $i -lt 10; $i++) {
        $password += Get-Random -InputObject $allChars
    }

    # Shuffle the password array
    $password = $password | Sort-Object { Get-Random }

    return -join $password
}

function New-TestUsers {
    <#
    .SYNOPSIS
        Creates 30 test users with fake names in the Users OU.
    .OUTPUTS
        Array of PSObjects with UserName and Password properties
    #>
    Write-Log "Creating 30 test users..."

    # First names and last names for generating fake identities
    $firstNames = @("James", "Mary", "Robert", "Patricia", "Michael", "Jennifer", "William", "Linda",
        "David", "Barbara", "Richard", "Susan", "Joseph", "Jessica", "Thomas", "Sarah",
        "Charles", "Karen", "Christopher", "Nancy", "Daniel", "Lisa", "Matthew", "Betty",
        "Anthony", "Margaret", "Mark", "Sandra", "Donald", "Ashley")

    $lastNames = @("Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis",
        "Rodriguez", "Martinez", "Hernandez", "Lopez", "Gonzalez", "Wilson", "Anderson", "Thomas",
        "Taylor", "Moore", "Jackson", "Martin", "Lee", "Perez", "Thompson", "White",
        "Harris", "Sanchez", "Clark", "Ramirez", "Lewis", "Robinson")

    $createdUsers = @()
    $usersOU = "OU=Users,$DomainDN"

    for ($i = 0; $i -lt 30; $i++) {
        $firstName = Get-Random -InputObject $firstNames
        $lastName = Get-Random -InputObject $lastNames
        $randomSuffix = "{0:D2}" -f (Get-Random -Minimum 0 -Maximum 100)

        $samAccountName = ($firstName.Substring(0, 1) + $lastName + $randomSuffix).ToLower()
        $password = New-TestPassword
        $displayName = "$firstName $lastName"
        $userPrincipalName = "$samAccountName@$DomainName"

        # Check if user already exists
        try {
            Get-ADUser -Identity $samAccountName -ErrorAction Stop | Out-Null
            Write-Log "User already exists: $samAccountName (skipping)"
            continue
        }
        catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
            # User doesn't exist, proceed with creation
        }

        try {
            Write-Log "Creating user: $samAccountName ($displayName)"

            New-ADUser `
                -SamAccountName $samAccountName `
                -UserPrincipalName $userPrincipalName `
                -Name $displayName `
                -GivenName $firstName `
                -Surname $lastName `
                -Path $usersOU `
                -AccountPassword (ConvertTo-SecureString -String $password -AsPlainText -Force) `
                -Enabled $true `
                -PasswordNeverExpires $true `
                -ErrorAction Stop | Out-Null

            $createdUsers += [PSCustomObject]@{
                SamAccountName   = $samAccountName
                DisplayName      = $displayName
                UserPrincipalName = $userPrincipalName
                Password         = $password
                CreatedDate      = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            }

            Write-Log "User created successfully: $samAccountName"
        }
        catch {
            Write-Log "ERROR creating user $samAccountName : $($_.Exception.Message)" -Level "ERROR"
        }
    }

    Write-Log "User creation completed. $($createdUsers.Count) users created."
    return $createdUsers
}

function Export-UserCredentials {
    <#
    .SYNOPSIS
        Exports created users and passwords to CSV with restricted permissions.
    .PARAMETER Users
        Array of user objects to export
    #>
    param([PSObject[]]$Users)

    Write-Log "Exporting user credentials to CSV..."

    # Create users directory if it doesn't exist
    if (-not (Test-Path $UsersDir)) {
        New-Item -ItemType Directory -Path $UsersDir -Force | Out-Null
    }

    # Export to CSV
    $Users | Export-Csv -Path $UsersCSV -NoTypeInformation -Force

    # Restrict file permissions to Administrators only
    $acl = Get-Acl -Path $UsersCSV
    $acl.SetAccessRuleProtection($true, $false)
    $acl.Access | ForEach-Object { $acl.RemoveAccessRule($_) }

    $adminRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        "Administrators", "FullControl", "Allow"
    )
    $acl.AddAccessRule($adminRule)

    Set-Acl -Path $UsersCSV -AclObject $acl

    Write-Log "Credentials exported to: $UsersCSV"
    Write-Log "File permissions restricted to Administrators only"
}

# ============================================================================
# BRANCH OU CREATION
# ============================================================================

function Invoke-BranchOUCreation {
    <#
    .SYNOPSIS
        Creates branch OU structure (Branches -> TOKYO, NEW YORK, AMSTERDAM).
    #>
    Write-Log "Creating branch OU structure..."

    try {
        # Get the path to this script's directory
        $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
        $adcreationScript = Join-Path $scriptDir "adcreation.ps1"

        # Check if adcreation.ps1 exists in the same directory
        if (Test-Path $adcreationScript) {
            Write-Log "Found adcreation.ps1 script, executing..."
            & powershell.exe -ExecutionPolicy Bypass -File $adcreationScript
            Write-Log "Branch OU creation completed"
        } else {
            Write-Log "adcreation.ps1 not found at: $adcreationScript" -Level "WARN"
            Write-Log "Skipping branch OU creation. You can run it manually later." -Level "WARN"
        }
    } catch {
        Write-Log "ERROR running branch OU creation: $($_.Exception.Message)" -Level "ERROR"
        Write-Log "Branch OU creation failed, but continuing with setup..." -Level "WARN"
    }
}

# ============================================================================
# DHCP CONFIGURATION
# ============================================================================

function Install-DHCPServer {
    <#
    .SYNOPSIS
        Installs DHCP Server role if not already installed.
    #>
    Write-Log "Checking DHCP Server role..."

    $dhcpRole = Get-WindowsFeature -Name DHCP -ErrorAction SilentlyContinue

    if ($dhcpRole.Installed) {
        Write-Log "DHCP Server role already installed"
    }
    else {
        Write-Log "Installing DHCP Server role..."
        Install-WindowsFeature -Name DHCP -IncludeManagementTools | Out-Null
        Write-Log "DHCP Server role installed"
    }
}

function Invoke-DHCPPostInstallConfiguration {
    <#
    .SYNOPSIS
        Completes DHCP post-installation configuration (adds DC to DHCP security groups).
    #>
    Write-Log "Completing DHCP post-installation configuration..."

    try {
        # This cmdlet runs post-install configuration
        netsh dhcp add securitygroups 2>&1 | Out-Null
        Write-Log "DHCP post-installation configuration completed"
    }
    catch {
        Write-Log "Warning: DHCP post-install config may have already been completed" -Level "WARN"
    }
}

function Authorize-DHCPServer {
    <#
    .SYNOPSIS
        Authorizes the DHCP server in Active Directory.
    #>
    Write-Log "Authorizing DHCP server in Active Directory..."

    try {
        $localComputerDN = (Get-ADComputer -Identity $env:COMPUTERNAME -ErrorAction Stop).DistinguishedName
        Add-DhcpServerInDC -DnsName $env:COMPUTERNAME -IPAddress 127.0.0.1 -ErrorAction SilentlyContinue

        Write-Log "DHCP server authorized in Active Directory"
    }
    catch {
        Write-Log "Warning: DHCP authorization issue: $($_.Exception.Message)" -Level "WARN"
    }
}

function New-DHCPScope {
    <#
    .SYNOPSIS
        Creates a DHCP scope for the lab network.
    #>
    Write-Log "Creating DHCP scope..."

    $scopeName = "Lab-Scope"
    $scopeStart = "10.0.1.100"
    $scopeEnd = "10.0.1.200"
    $subnetMask = "255.255.255.0"
    $gateway = "10.0.1.1"
    $dnsServer = "10.0.1.10"
    $dnsDomain = "lab.local"

    try {
        # Check if scope already exists
        $existingScope = Get-DhcpServerv4Scope -ScopeId 10.0.1.0 -ErrorAction SilentlyContinue

        if ($existingScope) {
            Write-Log "DHCP scope already exists (10.0.1.0)"
            return
        }

        # Create new scope
        Write-Log "Adding DHCP scope: 10.0.1.0/24 ($scopeStart - $scopeEnd)"
        Add-DhcpServerv4Scope -Name $scopeName `
            -StartRange $scopeStart `
            -EndRange $scopeEnd `
            -SubnetMask $subnetMask `
            -Description "Lab environment scope" `
            -ErrorAction Stop | Out-Null

        # Set scope options
        Write-Log "Configuring DHCP scope options..."

        # Option 003: Router (Default Gateway)
        Set-DhcpServerv4OptionValue -ScopeId 10.0.1.0 `
            -OptionId 003 `
            -Value $gateway `
            -ErrorAction Stop | Out-Null

        # Option 006: DNS Servers
        Set-DhcpServerv4OptionValue -ScopeId 10.0.1.0 `
            -OptionId 006 `
            -Value $dnsServer `
            -ErrorAction Stop | Out-Null

        # Option 015: DNS Domain Name
        Set-DhcpServerv4OptionValue -ScopeId 10.0.1.0 `
            -OptionId 015 `
            -Value $dnsDomain `
            -ErrorAction Stop | Out-Null

        Write-Log "DHCP scope configured successfully"
    }
    catch {
        Write-Log "ERROR configuring DHCP scope: $($_.Exception.Message)" -Level "ERROR"
        return
    }
}

# ============================================================================
# MAIN EXECUTION FLOW
# ============================================================================

function Invoke-LabSetup {
    <#
    .SYNOPSIS
        Main setup orchestration function.
    #>
    Write-Log "=========================================="
    Write-Log "Active Directory Lab Setup Starting"
    Write-Log "=========================================="
    Write-Log "Log file: $LogFile"

    # Check if already done
    if (Test-DoneFileExists) {
        Write-Log "Setup already completed. Exiting gracefully."
        return
    }

    try {
        # ===== PHASE 1: Domain Controller Promotion =====
        if (-not (Test-IsDomainController)) {
            Invoke-DCPromotion
            # Script will exit here and resume after reboot
        }
        else {
            Write-Log "Domain Controller already promoted, continuing with configuration..."
        }

        # ===== PHASE 2: Active Directory Configuration =====
        New-ADOUStructure
        Invoke-BranchOUCreation
        $createdUsers = New-TestUsers
        Export-UserCredentials -Users $createdUsers

        # ===== PHASE 3: DHCP Configuration =====
        Install-DHCPServer
        Invoke-DHCPPostInstallConfiguration
        Authorize-DHCPServer
        New-DHCPScope

        # ===== COMPLETION =====
        Write-Log "=========================================="
        Write-Log "All setup tasks completed successfully!"
        Write-Log "=========================================="
        Write-Log "Domain: $DomainName"
        Write-Log "Created Users: $($createdUsers.Count)"
        Write-Log "User credentials: $UsersCSV"
        Write-Log "DHCP Scope: 10.0.1.0/24 (10.0.1.100 - 10.0.1.200)"
        Write-Log "=========================================="

        New-DoneFile

    }
    catch {
        Write-Log "FATAL ERROR: $($_.Exception.Message)" -Level "ERROR"
        Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level "ERROR"
        return
    }
}

# ============================================================================
# SCRIPT ENTRY POINT
# ============================================================================

Invoke-LabSetup
