<# 
Simple ticket injection: update a user's proxyAddresses.
Run manually after DC promotion and lab configuration.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$SamAccountName,

    [Parameter(Mandatory = $true)]
    [string]$ProxyAddress
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Import-Module ActiveDirectory

try {
    # Add a single proxy address entry to the user
    Set-ADUser -Identity $SamAccountName -Add @{ proxyAddresses = $ProxyAddress }
    Write-Host "Updated proxyAddresses for '$SamAccountName' with '$ProxyAddress'."
} catch {
    Write-Error "Failed to update proxyAddresses for '$SamAccountName': $($_.Exception.Message)"
    exit 1
}
