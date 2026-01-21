# Automated Active Directory Lab with Terraform

This Terraform configuration automatically provisions and configures a complete Active Directory lab environment on Azure in a single `terraform apply` command.

## Overview

The lab setup creates:
- **DC01**: Windows Server 2022 VM configured as a Domain Controller
  - Domain: `lab.local` (configurable)
  - AD DS + DNS + DHCP fully installed and configured
  - Static private IP: 10.0.1.10
  - 30 auto-generated test users in OUs
  
- **SRV01**: Windows Server 2022 VM for testing/workstation
  - Static private IP: 10.0.1.20
  - Public IP for RDP access
  - Part of the lab domain

- **Network Infrastructure**:
  - VNet: 10.0.0.0/16
  - Subnet: 10.0.1.0/24
  - Network Security Group with rules for RDP, DNS, Kerberos, LDAP
  - DHCP scope: 10.0.1.100 - 10.0.1.200

## Two-Stage Bootstrap Process

The automation uses a robust two-stage bootstrap to handle the DC promotion reboot:

### Stage 1 (01-promote-dc.ps1)
1. Installs AD DS, DNS, and DHCP Windows Features
2. Promotes server to Domain Controller
3. Schedules Stage 2 to run automatically after reboot
4. Logs to `C:\LabBootstrap\logs\stage1.log`

**Timeline**: ~5-8 minutes

### Stage 2 (02-configure-lab.ps1)  
Runs automatically after Stage 1's reboot via Scheduled Task:
1. Waits for AD services to be ready (5 minute timeout)
2. Creates OU structure:
   - OU=Users
   - OU=Groups
   - OU=Workstations
   - OU=Servers
   - OU=Service Accounts
3. Creates 30 test users in OU=Users with generated passwords
4. Configures DHCP server with scope 10.0.1.100-10.0.1.200
5. Logs to `C:\LabBootstrap\logs\stage2.log`
6. Exports user credentials to `C:\LabBootstrap\users\created_users.csv`

**Timeline**: ~3-5 minutes

**Total Timeline**: 10-15 minutes from `terraform apply` to fully functional lab

## Prerequisites

1. **Azure Subscription** - Active subscription with sufficient quota for:
   - 2x Standard_B2ms VMs (or configured size)
   - 1x VNet + Subnet
   - 1x Public IP
   - 1x Network Security Group

2. **Terraform** - v1.4.0 or later

3. **Azure CLI** - Must be installed and authenticated:
   ```bash
   az login
   az account set --subscription <your-subscription-id>
   ```

4. **Credentials** - You need to provide:
   - `admin_username`: Local admin username (e.g., `azureuser`)
   - `admin_password`: Strong password (min 12 chars, uppercase, lowercase, number, special)
   - `dsrm_password`: DSRM password for DC (same requirements)

## How to Run

### 1. Clone the Repository
```bash
git clone https://github.com/your-org/your-repo.git
cd terraform
```

### 2. Configure Variables

Create a `terraform.tfvars` file:
```hcl
admin_username  = "azureuser"
admin_password  = "MyP@ssw0rd123!"
dsrm_password   = "MyDsrmp@ssw0rd123!"
domain_name     = "lab.local"  # Optional, defaults to lab.local
```

Or provide via command line:
```bash
terraform apply \
  -var="admin_username=azureuser" \
  -var="admin_password=MyP@ssw0rd123!" \
  -var="dsrm_password=MyDsrmp@ssw0rd123!"
```

### 3. Push Scripts to Public Repository

The Custom Script Extension requires public access to scripts. You have two options:

**Option A: Host on GitHub (Recommended)**
1. Push this repo (with scripts/ folder) to GitHub
2. Update the `fileUris` in `compute.tf` to point to your repo:
   ```hcl
   "https://raw.githubusercontent.com/YOUR-ORG/YOUR-REPO/main/scripts/01-promote-dc.ps1",
   "https://raw.githubusercontent.com/YOUR-ORG/YOUR-REPO/main/scripts/02-configure-lab.ps1"
   ```

**Option B: Upload to Azure Storage Account**
1. Create a storage container with public access
2. Upload scripts/ files
3. Update `fileUris` to storage URLs

### 4. Initialize and Apply

```bash
terraform init
terraform plan   # Review what will be created
terraform apply  # Apply the configuration
```

### 5. Wait for Completion

The extension logs can be checked during/after deployment. It takes 10-15 minutes for full completion.

## Verification

### Check Bootstrap Status

On the DC (via RDP after completion):

1. **Stage 1 Log**:
   ```powershell
   Get-Content C:\LabBootstrap\logs\stage1.log
   ```

2. **Stage 2 Log**:
   ```powershell
   Get-Content C:\LabBootstrap\logs\stage2.log
   ```

3. **Created Users**:
   ```powershell
   Import-Csv C:\LabBootstrap\users\created_users.csv | Format-Table
   ```

### Verify Active Directory

```powershell
# Check forest/domain
Get-ADForest
Get-ADDomain

# Check OUs
Get-ADOrganizationalUnit -Filter * | Format-Table Name, DistinguishedName

# Check users
Get-ADUser -Filter * -SearchBase "OU=Users,DC=lab,DC=local" | Format-Table SamAccountName, Name, Enabled
```

### Verify DNS

```powershell
# Check DNS zones
Get-DnsServerZone

# Test DNS resolution
Resolve-DnsName -Name dc01.lab.local
```

### Verify DHCP

```powershell
# Check DHCP server status
Get-DhcpServerv4Scope

# Check lease statistics
Get-DhcpServerv4ScopeStatistics
```

### Connect SRV01 to Domain

RDP to SRV01 using the public IP. Once connected:

```powershell
# Join domain (will prompt for credentials)
Add-Computer -DomainName lab.local -Credential (Get-Credential) -Restart
```

## Terraform Outputs

After successful `terraform apply`, view outputs:

```bash
terraform output
```

Key outputs:
- `dc_private_ip` - DC01 internal IP (10.0.1.10)
- `srv_public_ip` - SRV01 public IP for RDP access
- `domain_name` - AD domain (lab.local)
- `dhcp_scope` - DHCP range
- `rdp_allowed_cidr` - Your public IP (auto-detected)
- `bootstrap_status` - Where to find logs on the VM

## Idempotency

The scripts are designed to be idempotent:

- **Users**: Won't be recreated if they already exist
- **OUs**: Won't error if OU already exists
- **DC Promotion**: Skipped if server is already a DC
- **DHCP Scope**: Won't error if scope exists (though won't update)

**Rerunning `terraform apply` is safe** - it will not corrupt the environment or recreate resources unnecessarily.

## Password Storage

User credentials are stored in a CSV file on the DC:
```
C:\LabBootstrap\users\created_users.csv
```

**Permissions**: This file is ACL-restricted to Administrators only.

**Format**: Username, Password, FirstName, LastName

Example:
```
jsmith42,X7$kL2m9Pq@8R,John,Smith
```

## Network Topology

```
┌─────────────────────────────────────────────┐
│  Azure VNet: 10.0.0.0/16                    │
│                                             │
│  ┌─────────────────────────────────────┐   │
│  │  Subnet: 10.0.1.0/24                │   │
│  │                                     │   │
│  │  ┌──────────────┐ ┌──────────────┐ │   │
│  │  │   DC01       │ │   SRV01      │ │   │
│  │  │              │ │              │ │   │
│  │  │ 10.0.1.10    │ │ 10.0.1.20    │ │   │
│  │  │              │ │ + Public IP  │ │   │
│  │  │ AD DS        │ │              │ │   │
│  │  │ DNS: 10.0.1.10 │ DNS: 10.0.1.10 │   │
│  │  │ DHCP Server  │ │              │ │   │
│  │  │              │ │              │ │   │
│  │  └──────────────┘ └──────────────┘ │   │
│  │                                     │   │
│  │  Gateway: 10.0.1.1                 │   │
│  └─────────────────────────────────────┘   │
│                                             │
└─────────────────────────────────────────────┘
```

## Troubleshooting

### Bootstrap Failed to Run

Check the Azure VM Extension status:
```bash
terraform state show azurerm_virtual_machine_extension.dc_bootstrap_stage1
```

In Azure Portal: VM > Extensions + applications > Check status

### DC Promotion Hung

If the extension appears stuck after 15-20 minutes:
1. RDP to DC01 (use your public IP if configured)
2. Check logs: `Get-Content C:\LabBootstrap\logs\stage1.log`
3. Manually trigger reboot: `Restart-Computer -Force`

### Users Not Created

1. Wait 5+ minutes after DC reboot for Stage 2 to complete
2. Check Stage 2 log: `Get-Content C:\LabBootstrap\logs\stage2.log`
3. Verify Scheduled Task: `Get-ScheduledTask -TaskName "LabBootstrap-Stage2"`

### DHCP Not Working

1. Check DHCP service: `Get-Service DHCP`
2. If not running: `Start-Service DHCP`
3. Verify scope: `Get-DhcpServerv4Scope`
4. Check logs: `Get-EventLog -LogName "System" -Newest 50 | Where Source -eq "DHCP"`

## Cleanup

To destroy all Azure resources:

```bash
terraform destroy
```

This will:
- Delete both VMs
- Delete VNet, Subnet, and NSG
- Delete Public IPs
- Release all other resources

## Advanced Configuration

### Custom Domain Name

```bash
terraform apply -var="domain_name=corp.internal"
```

### Custom DHCP Range

```bash
terraform apply \
  -var="dhcp_scope_start=10.0.1.50" \
  -var="dhcp_scope_end=10.0.1.150"
```

### Larger VM Size

```bash
terraform apply -var="vm_size=Standard_B4ms"
```

## Scripts Reference

### 01-promote-dc.ps1
- **Location**: `scripts/01-promote-dc.ps1`
- **Runtime**: 5-8 minutes
- **Logs**: `C:\LabBootstrap\logs\stage1.log`
- **Actions**:
  - Install AD DS, DNS, DHCP
  - Configure static IP
  - Promote to DC
  - Schedule Stage 2

### 02-configure-lab.ps1
- **Location**: `scripts/02-configure-lab.ps1`
- **Runtime**: 3-5 minutes
- **Logs**: `C:\LabBootstrap\logs\stage2.log`
- **Actions**:
  - Create OUs
  - Create 30 test users
  - Configure DHCP
  - Export user credentials

## Security Notes

1. **Passwords**: Not logged or output in sensitive outputs
2. **DSRM Password**: Stored securely only in Terraform state (don't commit tfstate to Git)
3. **User Passwords**: Stored in CSV with file ACL restrictions
4. **RDP Access**: Auto-limited to your detected public IP
5. **WinRM**: Allowed only from Azure internal service tag

## Support & Contributions

For issues or improvements, please:
1. Check the logs first
2. Open an issue with logs attached
3. Submit PRs with improvements

## License

[Your License Here]

---

**Last Updated**: January 2026
**Terraform Version**: 1.4.0+
**Azure Provider**: 3.0+
