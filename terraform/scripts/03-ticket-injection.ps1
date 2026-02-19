<# 
Ticket injection: add jimmy.smith@lab.local to John Smith.
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

$targetSam = "jsmith01"
$proxyAddress = "SMTP:jimmy.smith@lab.local"

try {
    Set-ADUser -Identity $targetSam -Add @{ proxyAddresses = $proxyAddress }
} catch {
    exit 1
}
