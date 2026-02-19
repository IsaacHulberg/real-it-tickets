<# 
Creates Branch OUs (Tokyo, Houston, Amsterdam), standard sub-OUs, groups,
and 50 users assigned to random groups.
Run from elevated PowerShell on the DC.
#>

param(
    [int]$UserCount = 50,
    [string]$DefaultUserPassword = "TempP@ssw0rd123!"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Import-Module ActiveDirectory

function Ensure-OU {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $dn = "OU=$Name,$Path"
    try {
        $existing = Get-ADOrganizationalUnit -Identity $dn -ErrorAction Stop
        if ($existing) {
            Write-Host "Exists OU:  $dn"
            return $dn
        }
    } catch {
        # Not found or not ready yet; attempt creation below
    }

    New-ADOrganizationalUnit -Name $Name -Path $Path -ProtectedFromAccidentalDeletion $false | Out-Null
    Write-Host "Created OU: $dn"
    return $dn
}

function Ensure-Group {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $existing = Get-ADGroup -Filter "Name -eq '$Name'" -SearchBase $Path -ErrorAction SilentlyContinue
    if (-not $existing) {
        New-ADGroup -Name $Name -SamAccountName $Name -GroupScope Global -GroupCategory Security -Path $Path | Out-Null
        Write-Host "Created Group: $Name"
    } else {
        Write-Host "Exists Group:  $Name"
    }
}

$domain = Get-ADDomain
$baseDN = $domain.DistinguishedName

# Ensure the domain root object is accessible before creating OUs
$maxAttempts = 20
for ($i = 1; $i -le $maxAttempts; $i++) {
    try {
        $null = Get-ADObject -Identity $baseDN -ErrorAction Stop
        break
    } catch {
        if ($i -eq $maxAttempts) {
            throw "Domain root '$baseDN' not accessible after $maxAttempts attempts."
        }
        Start-Sleep -Seconds 5
    }
}

$branchesRoot = Ensure-OU -Name "Branches" -Path $baseDN

$branches = @("Tokyo", "Houston", "Amsterdam")
$subOUs = @("Users", "Groups", "Workstations")

# Create branch OUs and standard sub-OUs
$branchMap = @{}
foreach ($branch in $branches) {
    $branchDN = Ensure-OU -Name $branch -Path $branchesRoot
    $branchSubOUs = @{}
    foreach ($sub in $subOUs) {
        $branchSubOUs[$sub] = Ensure-OU -Name $sub -Path $branchDN
    }
    $branchMap[$branch] = $branchSubOUs
}

# Create groups under each branch's Groups OU
$groupsByBranch = @{}
foreach ($branch in $branches) {
    $groupPath = $branchMap[$branch]["Groups"]
    $groupNames = @(
        "$branch-Group1",
        "$branch-Group2",
        "$branch-Group3",
        "$branch-Group4",
        "$branch-Group5"
    )
    foreach ($g in $groupNames) {
        Ensure-Group -Name $g -Path $groupPath
    }
    $groupsByBranch[$branch] = $groupNames
}

# Generate users and assign to random groups
$firstNames = @("John","Jane","Michael","Sarah","David","Emily","Robert","Jessica","James","Ashley",
    "William","Brittany","Richard","Hannah","Joseph","Lauren","Thomas","Sophia","Charles","Olivia",
    "Christopher","Ava","Daniel","Isabella","Matthew","Mia","Mark","Charlotte","Donald","Amelia")

$lastNames = @("Smith","Johnson","Williams","Brown","Jones","Miller","Davis","Rodriguez","Martinez","Hernandez",
    "Lopez","Gonzalez","Wilson","Anderson","Thomas","Taylor","Moore","Jackson","Martin","Lee",
    "Perez","Thompson","White","Harris","Sanchez","Clark","Ramirez","Lewis","Robinson","Walker")

$securePassword = ConvertTo-SecureString $DefaultUserPassword -AsPlainText -Force

$created = 0
$index = 0
while ($created -lt $UserCount) {
    $first = $firstNames[$index % $firstNames.Count]
    $last = $lastNames[$index % $lastNames.Count]
    $suffix = "{0:D2}" -f ($index + 1)
    $sam = ("{0}{1}{2}" -f $first.Substring(0,1), $last, $suffix).ToLower()

    if (-not (Get-ADUser -Filter "SamAccountName -eq '$sam'" -ErrorAction SilentlyContinue)) {
        $branch = $branches[$index % $branches.Count]
        $userOU = $branchMap[$branch]["Users"]
        $group = $groupsByBranch[$branch][$index % $groupsByBranch[$branch].Count]

        New-ADUser -SamAccountName $sam `
            -UserPrincipalName "$sam@$($domain.DNSRoot)" `
            -Name "$first $last" `
            -GivenName $first `
            -Surname $last `
            -Path $userOU `
            -AccountPassword $securePassword `
            -Enabled $true `
            -PasswordNeverExpires $true `
            -ChangePasswordAtLogon $false | Out-Null

        Add-ADGroupMember -Identity $group -Members $sam

        Write-Host "Created user: $sam ($branch) -> $group"
        $created++
    }

    $index++
}

Write-Host "Done. Created $created users across branches."
