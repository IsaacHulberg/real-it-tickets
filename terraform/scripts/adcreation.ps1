<# 
adcreation.ps1
Creates:
OU=Branches
  OU=TOKYO
    OU=Users, OU=Computers, OU=Groups, plus optional extra sub-OUs
  OU=NEW YORK
    OU=Users, OU=Computers, OU=Groups, plus optional extra sub-OUs
  OU=AMSTERDAM
    OU=Users, OU=Computers, OU=Groups, plus optional extra sub-OUs
#>

$ErrorActionPreference = "Continue"

Import-Module ActiveDirectory

# ---- CONFIG ----
$rootOuName = "Branches"
$branches   = @("TOKYO", "NEW YORK", "AMSTERDAM")

# Required child OUs under each branch
$standardChildOUs = @("Users", "Computers", "Groups")

# Optional extra sub-OUs under each branch (add/edit as you want)
$extraChildOUs = @(
  "SubOUs",        # example
  "Servers",       # example
  "Workstations"   # example
)

# If you don't want extras, set: $extraChildOUs = @()

# ---- HELPERS ----
function Ensure-OU {
  param(
    [Parameter(Mandatory=$true)][string]$Name,
    [Parameter(Mandatory=$true)][string]$Path
  )

  $dn = "OU=$Name,$Path"
  $existing = Get-ADOrganizationalUnit -LDAPFilter "(distinguishedName=$dn)" -ErrorAction SilentlyContinue

  if (-not $existing) {
    New-ADOrganizationalUnit -Name $Name -Path $Path -ProtectedFromAccidentalDeletion $false | Out-Null
    Write-Host "Created OU: $dn"
  } else {
    Write-Host "Exists OU:  $dn"
  }

  return $dn
}

# ---- MAIN ----
$domainDn = (Get-ADDomain).DistinguishedName

# Create root OU=Branches
$branchesDn = Ensure-OU -Name $rootOuName -Path $domainDn

foreach ($branch in $branches) {
  # Create branch OU under Branches
  $branchDn = Ensure-OU -Name $branch -Path $branchesDn

  # Create standard child OUs
  foreach ($child in $standardChildOUs) {
    Ensure-OU -Name $child -Path $branchDn | Out-Null
  }

  # Create extra child OUs (optional)
  foreach ($child in $extraChildOUs) {
    Ensure-OU -Name $child -Path $branchDn | Out-Null
  }
}

Write-Host "`nDone. OUs created/verified under OU=$rootOuName,$domainDn"
