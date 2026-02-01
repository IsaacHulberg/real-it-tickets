param(
  [int]$UserCount = 30
)

$ErrorActionPreference = "Continue"

$BootstrapRoot = "C:\LabBootstrap"
$LogDir = Join-Path $BootstrapRoot "logs"
$LogFile = Join-Path $LogDir "stage2.log"
$RunOnceFile = Join-Path $BootstrapRoot "stage2.ran"

function Ensure-Directory {
  param([string]$Path)
  if (-not (Test-Path -Path $Path)) {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
  }
}

function Write-Log {
  param(
    [string]$Message,
    [string]$Level = "INFO"
  )
  $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  Add-Content -Path $LogFile -Value "$timestamp [$Level] $Message"
}

function Wait-ForActiveDirectory {
  param(
    [int]$Retries = 30,
    [int]$DelaySeconds = 10
  )
  Import-Module ActiveDirectory -ErrorAction Stop

  for ($attempt = 1; $attempt -le $Retries; $attempt++) {
    try {
      $domain = Get-ADDomain -ErrorAction Stop
      Write-Log "Active Directory ready. Domain: $($domain.DnsRoot)."
      return $domain
    } catch {
      Write-Log "AD not ready (attempt $attempt/$Retries): $($_.Exception.Message)"
      Start-Sleep -Seconds $DelaySeconds
    }
  }

  Write-Log "Active Directory not ready after $Retries attempts." "ERROR"
  return $null
}

try {
  Ensure-Directory -Path $BootstrapRoot
  Ensure-Directory -Path $LogDir
  Write-Log "Stage2 create mock users starting."

  if (Test-Path -Path $RunOnceFile) {
    Write-Log "Run-once flag exists at $RunOnceFile. Exiting."
    return
  }

  $domain = Wait-ForActiveDirectory
  if (-not $domain) {
    Write-Log "Active Directory not ready. Exiting Stage2." "ERROR"
    return
  }
  $domainDn = $domain.DistinguishedName
  $dnsRoot = $domain.DnsRoot

  $ouName = "LabUsers"
  $ou = Get-ADOrganizationalUnit -LDAPFilter "(ou=$ouName)" -SearchBase $domainDn -ErrorAction SilentlyContinue
  if (-not $ou) {
    $ou = New-ADOrganizationalUnit -Name $ouName -Path $domainDn -ProtectedFromAccidentalDeletion:$false
    Write-Log "Created OU $ouName at $domainDn."
  } else {
    Write-Log "OU $ouName already exists."
  }

  $ouDn = $ou.DistinguishedName
  $password = ConvertTo-SecureString "P@ssw0rd!123" -AsPlainText -Force

  for ($i = 1; $i -le $UserCount; $i++) {
    $sam = ("labuser{0:D2}" -f $i)
    $upn = "$sam@$dnsRoot"

    $existing = Get-ADUser -Filter "SamAccountName -eq '$sam'" -ErrorAction SilentlyContinue
    if ($existing) {
      Write-Log "User $sam already exists. Skipping."
      continue
    }

    New-ADUser -Name $sam -SamAccountName $sam -UserPrincipalName $upn -Path $ouDn -AccountPassword $password -Enabled $true -ChangePasswordAtLogon $false
    Set-ADUser -Identity $sam -PasswordNeverExpires $true -ChangePasswordAtLogon $false
    Write-Log "Created user $sam."
  }

  Set-Content -Path $RunOnceFile -Value (Get-Date -Format "yyyy-MM-dd HH:mm:ss") -Force
  Write-Log "Stage2 completed successfully. Run-once flag written to $RunOnceFile."
} catch {
  Write-Log "Stage2 failed: $($_.Exception.Message)" "ERROR"
  return
}
