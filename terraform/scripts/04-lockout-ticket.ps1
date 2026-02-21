<#
Ticket injection: lock out an existing lab user account in Active Directory.

Behavior:
- Finds users under OU=Branches (created by your lab scripts)
- Locks a specific known lab user to be deterministic
- Locks the account using Lock-ADAccount

Run from elevated PowerShell on the DC.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Avoid execution policy prompts when launched via double-click
try {
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
} catch {
    # Ignore if policy cannot be set in this context
}

Import-Module ActiveDirectory

$domain = Get-ADDomain -ErrorAction Stop
$targetSam = "jjohnson02"

$target = Get-ADUser -Identity $targetSam -ErrorAction SilentlyContinue
if (-not $target) {
    throw "Target user '$targetSam' not found. Run 02-configure-lab.ps1 first to create lab users."
}

# Lockout (idempotent-ish: if already locked, it remains locked)
Lock-ADAccount -Identity $targetSam -ErrorAction Stop
