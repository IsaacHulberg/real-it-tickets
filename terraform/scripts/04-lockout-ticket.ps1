<#
Ticket injection: lock out an existing lab user account in Active Directory.

Behavior:
- Targets a specific known lab user (jjohnson02 / Jane Johnson)
- Triggers an account lockout by submitting bad password attempts
- The default domain lockout threshold is typically 5 attempts

Run from elevated PowerShell on the DC.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Avoid execution policy prompts when launched via double-click
try {
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
} catch {}

Import-Module ActiveDirectory

$targetSam = "jjohnson02"
$domain = (Get-ADDomain).DNSRoot

$target = Get-ADUser -Identity $targetSam -ErrorAction SilentlyContinue
if (-not $target) {
    throw "Target user '$targetSam' not found. Run 02-configure-lab.ps1 first to create lab users."
}

# First ensure a lockout policy exists (set threshold to 3 bad attempts, 30 min lockout)
Set-ADDefaultDomainPasswordPolicy -Identity $domain `
    -LockoutThreshold 3 `
    -LockoutDuration "00:30:00" `
    -LockoutObservationWindow "00:30:00" `
    -ErrorAction Stop

# Force bad password attempts to trigger lockout
Add-Type -AssemblyName System.DirectoryServices.AccountManagement
$ctx = New-Object System.DirectoryServices.AccountManagement.PrincipalContext(
    [System.DirectoryServices.AccountManagement.ContextType]::Domain, $domain
)

for ($i = 0; $i -lt 5; $i++) {
    $ctx.ValidateCredentials($targetSam, "WrongPassword!$i") | Out-Null
}

$ctx.Dispose()

# Verify lockout
$locked = (Get-ADUser -Identity $targetSam -Properties LockedOut).LockedOut
if ($locked) {
    # success - silent
} else {
    throw "Failed to lock out '$targetSam'. Check the domain lockout policy."
}
