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
    [string]$AdminUsername = "tempadmin",
    [string]$AdminPassword = "Temppassword123!@#",
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

# Critical error tracking
$script:HadCriticalError = $false

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

function Ensure-OU {
    param(
        [string]$Name,
        [string]$Path
    )

    $ouDN = "OU=$Name,$Path"
    try {
        if (-not (Get-ADOrganizationalUnit -Identity $ouDN -ErrorAction SilentlyContinue)) {
            New-ADOrganizationalUnit -Name $Name -Path $Path -ErrorAction Stop
            Write-Log "Created OU: $Name"
        } else {
            Write-Log "OU already exists: $Name"
        }
        return $ouDN
    } catch {
        Write-Log "ERROR creating OU $Name : $($_.Exception.Message)"
        $script:HadCriticalError = $true
        return $null
    }
}

function Create-ADOUs {
    param([string]$Domain)

    Write-Log "Creating Active Directory OUs..."

    # Get the actual domain DN from AD instead of constructing it
    try {
        $domainObj = Get-ADDomain -ErrorAction Stop
        $baseDN = $domainObj.DistinguishedName
        Write-Log "Domain DN: $baseDN"
    } catch {
        Write-Log "CRITICAL: Cannot get domain information: $($_.Exception.Message)"
        $script:HadCriticalError = $true
        return $null
    }

    # Try a much simpler approach first - create OUs directly under domain root
    Write-Log "Attempting to create Lab OU structure directly under domain root..."

    # Create Lab root OU directly under domain
    $labDN = "OU=Lab,$baseDN"
    try {
        Write-Log "Creating Lab OU: $labDN"
        if (-not (Get-ADOrganizationalUnit -Identity $labDN -ErrorAction SilentlyContinue)) {
            New-ADOrganizationalUnit -Name "Lab" -Path $baseDN -ErrorAction Stop
            Write-Log "Successfully created Lab OU under domain root"
        } else {
            Write-Log "Lab OU already exists under domain root"
        }
    } catch {
        Write-Log "Failed to create Lab OU under domain root: $($_.Exception.Message)"
        Write-Log "This suggests the domain is not ready for OU creation yet."
        Write-Log "The domain controller may still be initializing after promotion."
        $script:HadCriticalError = $true
        return $null
    }

    # Now try to create the _Madison branch under the Lab OU instead
    Write-Log "Creating _Madison branch under Lab OU..."
    $madisonDN = "OU=_Madison,$labDN"
    try {
        Write-Log "Creating _Madison OU: $madisonDN"
        New-ADOrganizationalUnit -Name "_Madison" -Path $labDN -ErrorAction Stop
        Write-Log "Successfully created _Madison OU"
    } catch {
        Write-Log "Failed to create _Madison OU: $($_.Exception.Message)"
        Write-Log "Will continue without _Madison branch - creating OUs directly under Lab"
        $madisonDN = $labDN  # Fall back to using Lab as the root
    }

    # Create child OUs under the Madison DN (or Lab if Madison failed)
    $childOUs = @("Lab-Users", "Groups", "Workstations", "Servers", "Service Accounts")
    foreach ($ou in $childOUs) {
        $childOUDN = "OU=$ou,$madisonDN"
        try {
            Write-Log "Creating OU: $childOUDN"
            if (-not (Get-ADOrganizationalUnit -Identity $childOUDN -ErrorAction SilentlyContinue)) {
                New-ADOrganizationalUnit -Name $ou -Path $madisonDN -ErrorAction Stop
                Write-Log "Successfully created $ou OU"
            } else {
                Write-Log "$ou OU already exists"
            }
        } catch {
            Write-Log "Failed to create $ou OU: $($_.Exception.Message)"
            # Don't fail completely for child OU creation - continue
        }
    }

    # Verify Lab-Users OU exists (this is critical for user creation)
    $labUsersPath = if ($madisonDN -eq $labDN) { "OU=Lab-Users,$labDN" } else { "OU=Lab-Users,$madisonDN" }
    if (-not (Get-ADOrganizationalUnit -Identity $labUsersPath -ErrorAction SilentlyContinue)) {
        Write-Log "CRITICAL: Lab-Users OU was not created successfully - cannot create users"
        $script:HadCriticalError = $true
        return $null
    }

    Write-Log "OU structure created successfully"
    Write-Log "Lab-Users path: $labUsersPath"
    return $madisonDN
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
        [string]$CSVPath,
        [string]$LabRootDN
    )

    Write-Log "Creating $Count test users in Active Directory..."

    $userOUDN = "OU=Lab-Users,$LabRootDN"
    
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
    $userCreationErrors = 0
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
            $userCreationErrors++
        }

        $userIndex++
    }

    # Check for critical error: 0 users created AND there were creation errors
    if ($createdUsers.Count -eq 0 -and $userCreationErrors -gt 0) {
        Write-Log "CRITICAL: Failed to create any users and encountered creation errors"
        $script:HadCriticalError = $true
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
        # Install DHCP role and management tools
        Write-Log "Installing DHCP Server role and management tools..."
        Install-WindowsFeature -Name DHCP -IncludeManagementTools -ErrorAction Stop | Out-Null
        Write-Log "DHCP role installed successfully"

        # Import DHCP module
        Write-Log "Importing DhcpServer module..."
        Import-Module DhcpServer -ErrorAction Stop
        Write-Log "DhcpServer module imported successfully"

        # Get server IP address for authorization (exclude APIPA/link-local)
        $serverIP = Get-NetIPAddress -AddressFamily IPv4 |
            Where-Object {
                $_.IPAddress -notlike "169.254.*" -and
                $_.IPAddress -notlike "127.*" -and
                $_.InterfaceAlias -notlike "*Loopback*"
            } |
            Select-Object -First 1 -ExpandProperty IPAddress

        if (-not $serverIP) {
            throw "Could not determine server IP address for DHCP authorization"
        }

        Write-Log "Using server IP for DHCP authorization: $serverIP"

        # Authorize DHCP server in AD
        Write-Log "Authorizing DHCP server in Active Directory..."
        $serverFQDN = "$env:COMPUTERNAME.$Domain"
        Add-DhcpServerInDC -DnsName $serverFQDN -IPAddress $serverIP -ErrorAction Stop
        Write-Log "DHCP server authorized in Active Directory"

        # Wait a moment for DHCP service to be ready
        Start-Sleep -Seconds 5

        # Create DHCP scope if it doesn't exist
        $scopeId = [ipaddress]"10.0.1.0"
        $scopeName = "Lab-Subnet-10.0.1.0"

        Write-Log "Checking for existing DHCP scope: $scopeId"
        $existingScope = Get-DhcpServerv4Scope -ScopeId $scopeId -ErrorAction SilentlyContinue

        if ($existingScope) {
            Write-Log "DHCP scope already exists: $scopeId"
        } else {
            Write-Log "Creating DHCP scope: $scopeName ($scopeId) with range $ScopeStart - $ScopeEnd"
            Add-DhcpServerv4Scope `
                -Name $scopeName `
                -StartRange $ScopeStart `
                -EndRange $ScopeEnd `
                -SubnetMask "255.255.255.0" `
                -State Active `
                -ErrorAction Stop | Out-Null
            Write-Log "DHCP scope created successfully"
        }

        # Configure DHCP options
        Write-Log "Configuring DHCP scope options..."
        Set-DhcpServerv4OptionValue -ScopeId $scopeId `
            -OptionId 003 `  # Router
            -Value "10.0.1.1" `
            -ErrorAction Stop | Out-Null

        Set-DhcpServerv4OptionValue -ScopeId $scopeId `
            -OptionId 006 `  # DNS Servers
            -Value "10.0.1.10" `
            -ErrorAction Stop | Out-Null

        Set-DhcpServerv4OptionValue -ScopeId $scopeId `
            -OptionId 015 `  # DNS Domain Name
            -Value $Domain `
            -ErrorAction Stop | Out-Null

        Write-Log "DHCP configuration completed"
        Write-Log "  - Scope: $scopeName"
        Write-Log "  - Network: 10.0.1.0/24"
        Write-Log "  - Range: $ScopeStart - $ScopeEnd"
        Write-Log "  - Gateway: 10.0.1.1"
        Write-Log "  - DNS: 10.0.1.10"
        Write-Log "  - Domain: $Domain"

    } catch {
        Write-Log "ERROR configuring DHCP: $($_.Exception.Message)"
        $script:HadCriticalError = $true
    }
}

try {
    Write-Log "=== Stage 2: AD Configuration, User Creation, and DHCP Setup ==="
    Write-Log "Domain Name: $DomainName"
    Write-Log "Timestamp: $(Get-Date)"
    
    # Wait for AD to be ready
    if (-not (Wait-ForActiveDirectory)) {
        Write-Log "CRITICAL: AD services did not become ready. Aborting Stage 2."
        Write-Log "Press any key to exit..."
        try {
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        } catch {
            Start-Sleep -Seconds 10
        }
        exit 1
    }

    # Additional wait to ensure domain is fully initialized
    Write-Log "Waiting additional 10 seconds for domain initialization..."
    Start-Sleep -Seconds 10

    # Create OUs and get Lab root DN
    $labRootDN = Create-ADOUs -Domain $DomainName
    if (-not $labRootDN) {
        Write-Log "CRITICAL: Failed to create OU structure. Aborting Stage 2."
        Write-Log "Press any key to exit..."
        try {
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        } catch {
            Start-Sleep -Seconds 10
        }
        exit 1
    }

    # Create test users
    Create-TestUsers -Domain $DomainName -Count $NumberOfUsers -CSVPath $usersCSV -LabRootDN $labRootDN

    # Configure DHCP
    Configure-DHCP -ScopeStart $DHCPScopeStart -ScopeEnd $DHCPScopeEnd -Domain $DomainName

    # Check for critical errors
    if ($script:HadCriticalError) {
        Write-Log "CRITICAL: Stage 2 encountered critical errors. Lab setup incomplete."
        Write-Log "Check the log file for details: $logFile"
        Write-Log "Press any key to exit..."
        try {
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        } catch {
            Start-Sleep -Seconds 10
        }
        exit 1
    }

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
    Write-Log "Press any key to exit..."
    try {
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    } catch {
        Start-Sleep -Seconds 10
    }
    exit 1
}
