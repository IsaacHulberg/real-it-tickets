#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Stage 2: Configure AD OUs, create test users, and setup DHCP
    Logs to C:\LabBootstrap\logs\stage2.log
.DESCRIPTION
    This script runs automatically after DC promotion reboot via Scheduled Task.
    It waits for AD services to be ready, creates OUs, generates 30 test users, and configures DHCP.
#>

param(
    [string]$DomainName = "lab.local",
    [string]$AdminUsername = "Administrator",
    [string]$AdminPassword = "P@ssw0rd123!",
    [string]$DHCPScopeStart = "10.0.1.100",
    [string]$DHCPScopeEnd = "10.0.1.200",
    [int]$NumberOfUsers = 30
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Setup logging and directories
$logDir = "C:\LabBootstrap\logs"
$scriptsDir = "C:\LabBootstrap\scripts"
$usersDir = "C:\LabBootstrap\users"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
if (-not (Test-Path $usersDir)) { New-Item -ItemType Directory -Path $usersDir -Force | Out-Null }

$logFile = Join-Path $logDir "stage2.log"
$usersCSV = Join-Path $usersDir "created_users.csv"

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    Add-Content -Path $logFile -Value $logMessage
    Write-Host $logMessage
}

function Wait-ForActiveDirectory {
    param([int]$MaxAttempts = 60, [int]$WaitSeconds = 5)
    Write-Log "Waiting for Active Directory services to be ready..."
    
    for ($i = 1; $i -le $MaxAttempts; $i++) {
        try {
            $domain = Get-ADDomain -ErrorAction Stop
            Write-Log "AD is ready! Domain: $($domain.DNSRoot)"
            return $true
        } catch {
            Write-Log "Attempt $i/$MaxAttempts - AD not ready yet. Waiting $WaitSeconds seconds..."
            Start-Sleep -Seconds $WaitSeconds
        }
    }
    
    Write-Log "ERROR: Active Directory did not become ready within $(($MaxAttempts * $WaitSeconds) / 60) minutes"
    return $false
}

function Create-ADOUs {
    param([string]$Domain)
    
    Write-Log "Creating Active Directory OUs..."
    
    $dc = ($Domain -split '\.') | ForEach-Object { "DC=$_" }
    $baseDN = $dc -join ','
    
    $ouNames = @("Users", "Groups", "Workstations", "Servers", "Service Accounts")
    
    foreach ($ou in $ouNames) {
        $ouDN = "OU=$ou,$baseDN"
        try {
            if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$ou'" -SearchBase $baseDN -ErrorAction SilentlyContinue)) {
                New-ADOrganizationalUnit -Name $ou -Path $baseDN -ErrorAction Stop
                Write-Log "Created OU: $ou"
            } else {
                Write-Log "OU already exists: $ou"
            }
        } catch {
            Write-Log "ERROR creating OU $ou : $($_.Exception.Message)"
        }
    }
}

function Generate-TestPassword {
    param([int]$Length = 14)
    
    $upper = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    $lower = "abcdefghijklmnopqrstuvwxyz"
    $numbers = "0123456789"
    $special = "!@#$%^&*"
    
    $password = ""
    $password += $upper[(Get-Random -Maximum $upper.Length)]
    $password += $lower[(Get-Random -Maximum $lower.Length)]
    $password += $numbers[(Get-Random -Maximum $numbers.Length)]
    $password += $numbers[(Get-Random -Maximum $numbers.Length)]
    $password += $special[(Get-Random -Maximum $special.Length)]
    
    $all = $upper + $lower + $numbers + $special
    for ($i = 5; $i -lt $Length; $i++) {
        $password += $all[(Get-Random -Maximum $all.Length)]
    }
    
    return -join ($password.ToCharArray() | Sort-Object { Get-Random })
}

function Create-TestUsers {
    param(
        [string]$Domain,
        [int]$Count,
        [string]$CSVPath
    )
    
    Write-Log "Creating $Count test users in Active Directory..."
    
    $dc = ($Domain -split '\.') | ForEach-Object { "DC=$_" }
    $baseDN = $dc -join ','
    $userOUDN = "OU=Users,$baseDN"
    
    # Predefined names for reproducibility
    $firstNames = @("John", "Jane", "Michael", "Sarah", "David", "Emily", "Robert", "Jessica", "James", "Ashley",
                    "William", "Brittany", "Richard", "Hannah", "Joseph", "Lauren", "Thomas", "Sophia", "Charles", "Olivia",
                    "Christopher", "Ava", "Daniel", "Isabella", "Matthew", "Mia", "Mark", "Charlotte", "Donald", "Amelia")
    
    $lastNames = @("Smith", "Johnson", "Williams", "Brown", "Jones", "Miller", "Davis", "Rodriguez", "Martinez", "Hernandez",
                   "Lopez", "Gonzalez", "Wilson", "Anderson", "Thomas", "Taylor", "Moore", "Jackson", "Martin", "Lee",
                   "Perez", "Thompson", "White", "Harris", "Sanchez", "Clark", "Ramirez", "Lewis", "Robinson", "Walker")
    
    $existingUsers = @()
    try {
        $existingUsers = Get-ADUser -Filter * -SearchBase $userOUDN -ErrorAction SilentlyContinue | Select-Object -ExpandProperty SamAccountName
    } catch {
        Write-Log "First run - no existing users found"
    }
    
    $createdUsers = @()
    $userIndex = 0
    
    for ($i = 0; $i -lt $Count -and $userIndex -lt $firstNames.Count; $i++) {
        $firstName = $firstNames[$userIndex]
        $lastName = $lastNames[$userIndex]
        $samAccount = "$($firstName.Substring(0,1).ToLower())$($lastName.ToLower())$(Get-Random -Minimum 10 -Maximum 99)"
        
        if ($samAccount -in $existingUsers) {
            Write-Log "User already exists: $samAccount (skipping)"
            $userIndex++
            continue
        }
        
        try {
            $password = Generate-TestPassword
            $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
            
            New-ADUser -SamAccountName $samAccount `
                -UserPrincipalName "$samAccount@$Domain" `
                -Name "$firstName $lastName" `
                -GivenName $firstName `
                -Surname $lastName `
                -Path $userOUDN `
                -AccountPassword $securePassword `
                -PasswordNeverExpires $true `
                -Enabled $true `
                -ErrorAction Stop
            
            Write-Log "Created user: $samAccount"
            $createdUsers += @([PSCustomObject]@{
                Username = $samAccount
                Password = $password
                FirstName = $firstName
                LastName = $lastName
            })
        } catch {
            Write-Log "ERROR creating user $samAccount : $($_.Exception.Message)"
        }
        
        $userIndex++
    }
    
    # Export to CSV (append mode, but with headers if new file)
    if ($createdUsers.Count -gt 0) {
        if (Test-Path $CSVPath) {
            $createdUsers | Export-Csv -Path $CSVPath -Append -NoTypeInformation -Encoding UTF8
        } else {
            $createdUsers | Export-Csv -Path $CSVPath -NoTypeInformation -Encoding UTF8
        }
        
        # Set restrictive permissions on CSV (Administrators only)
        $acl = Get-Acl $CSVPath
        $acl.SetAccessRuleProtection($true, $false)
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule("BUILTIN\Administrators", "FullControl", "Allow")
        $acl.SetAccessRule($rule)
        Set-Acl -Path $CSVPath -AclObject $acl
        
        Write-Log "Exported $($createdUsers.Count) user credentials to $CSVPath (Administrators only)"
    } else {
        Write-Log "No new users created - all users already exist or user limit reached"
    }
}

function Configure-DHCP {
    param(
        [string]$ScopeStart,
        [string]$ScopeEnd,
        [string]$Domain
    )
    
    Write-Log "Configuring DHCP Server..."
    
    try {
        # Add DHCP server to domain
        Write-Log "Adding DHCP server to Active Directory..."
        Add-DhcpServerInDC -Confirm:$false -ErrorAction SilentlyContinue
        
        # Wait a moment for DHCP service to be ready
        Start-Sleep -Seconds 5
        
        # Create DHCP scope
        $scopeStart = $ScopeStart
        $scopeEnd = $ScopeEnd
        $scopeNetwork = "10.0.1.0"
        $scopeMask = "255.255.255.0"
        $scopeName = "Lab-Subnet-10.0.1.0"
        
        Write-Log "Creating DHCP scope: $scopeName ($scopeNetwork/$scopeMask) with range $scopeStart - $scopeEnd"
        
        try {
            Add-DhcpServerv4Scope `
                -Name $scopeName `
                -StartRange $scopeStart `
                -EndRange $scopeEnd `
                -SubnetMask $scopeMask `
                -State Active `
                -Confirm:$false `
                -ErrorAction Stop
            Write-Log "DHCP scope created successfully"
        } catch {
            Write-Log "DHCP scope may already exist: $($_.Exception.Message)"
        }
        
        # Configure DHCP options
        Write-Log "Configuring DHCP options..."
        Set-DhcpServerv4OptionValue -ScopeId $scopeNetwork `
            -DnsServer "10.0.1.10" `
            -Router "10.0.1.1" `
            -DnsDomain $Domain `
            -Confirm:$false -ErrorAction SilentlyContinue
        
        Write-Log "DHCP configuration completed"
        Write-Log "  - Scope: $scopeName"
        Write-Log "  - Network: $scopeNetwork/$scopeMask"
        Write-Log "  - Range: $scopeStart - $scopeEnd"
        Write-Log "  - Gateway: 10.0.1.1"
        Write-Log "  - DNS: 10.0.1.10"
        Write-Log "  - Domain: $Domain"
        
    } catch {
        Write-Log "ERROR configuring DHCP: $($_.Exception.Message)"
    }
}

try {
    Write-Log "=== Stage 2: AD Configuration, User Creation, and DHCP Setup ==="
    Write-Log "Domain Name: $DomainName"
    Write-Log "Timestamp: $(Get-Date)"
    
    # Wait for AD to be ready
    if (-not (Wait-ForActiveDirectory)) {
        Write-Log "CRITICAL: AD services did not become ready. Aborting Stage 2."
        exit 1
    }
    
    # Create OUs
    Create-ADOUs -Domain $DomainName
    
    # Create test users
    Create-TestUsers -Domain $DomainName -Count $NumberOfUsers -CSVPath $usersCSV
    
    # Configure DHCP
    Configure-DHCP -ScopeStart $DHCPScopeStart -ScopeEnd $DHCPScopeEnd -Domain $DomainName
    
    Write-Log "=== Stage 2 Completed Successfully ==="
    Write-Log "Lab is ready!"
    Write-Log "Users CSV: $usersCSV"
    
    # Remove scheduled task after successful completion
    $taskName = "LabBootstrap-Stage2"
    $taskPath = "\LabBootstrap"
    if (Get-ScheduledTask -TaskPath $taskPath -TaskName $taskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskPath $taskPath -TaskName $taskName -Confirm:$false
        Write-Log "Scheduled task removed (one-time execution complete)"
    }

} catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    Write-Log "Stack trace: $($_.ScriptStackTrace)"
    exit 1
}
