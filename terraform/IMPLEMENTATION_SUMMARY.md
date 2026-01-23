# AD Lab Implementation Summary

## Overview
Fully automated Active Directory lab provisioning on Azure using Terraform with two-stage PowerShell bootstrap process.

## Files Modified/Created

### Terraform Configuration Files

#### 1. **variables.tf** (MODIFIED)
Added new variables for AD lab configuration:
- `domain_name`: AD domain (default: lab.local)
- `dsrm_password`: DSRM password for DC promotion (sensitive)
- `dhcp_scope_start` / `dhcp_scope_end`: DHCP scope range
- `number_of_test_users`: Number of test users to create (default: 30)

#### 2. **outputs.tf** (MODIFIED)
Enhanced outputs to provide useful information:
- `dc_private_ip`: DC01's private IP (10.0.1.10)
- `srv_private_ip`: SRV01's private IP (10.0.1.20)
- `srv_public_ip`: SRV01's public IP for RDP access
- `admin_username`: Configured admin username
- `domain_name`: AD domain name
- `dhcp_scope`: DHCP scope range
- `rdp_allowed_cidr`: Auto-detected public IP for RDP access
- `bootstrap_status`: Location of log files

Removed: `admin_password` from outputs (security best practice)

#### 3. **compute.tf** (MODIFIED)
Added:
- VM Extension `azurerm_virtual_machine_extension.dc_bootstrap_stage1`
  - Type: CustomScriptExtension
  - Runs `01-promote-dc.ps1` on DC01 after VM creation
  - Passes domain name, DSRM password, and admin credentials

#### 4. **subnet-nsg.tf** (MODIFIED)
Added:
- `azurerm_network_security_group_rule.allow_winrm`
  - Allows WinRM (5985-5986) from Azure service tag
  - Required for CustomScriptExtension execution
  - Priority: 200 (above existing rules)

### PowerShell Scripts (NEW)

#### 5. **scripts/01-promote-dc.ps1** (NEW)
Stage 1 bootstrap script (5-8 minutes):
- Installs AD DS, DNS, DHCP Windows Features
- Configures static IP (10.0.1.10)
- Promotes server to Domain Controller
- Creates DSRM secure password
- Schedules Stage 2 via Scheduled Task
- Comprehensive error handling and logging
- Output: `C:\LabBootstrap\logs\stage1.log`

**Key Features:**
- Idempotent: Checks if already DC, skips if true
- Robust: Try/catch error handling, detailed logging
- Self-healing: Schedules automatic Stage 2 after reboot
- Secure: DSRM password handled securely

#### 6. **scripts/02-configure-lab.ps1** (NEW)
Stage 2 bootstrap script (3-5 minutes):
- Waits for AD services (60-second retry, 5-second intervals)
- Creates OU structure:
  - OU=Users
  - OU=Groups
  - OU=Workstations
  - OU=Servers
  - OU=Service Accounts
- Generates 30 test users with:
  - Realistic first/last names (deterministic)
  - Random 14-character passwords (upper, lower, number, special)
  - Placed in OU=Users
  - Password never expires (lab environment)
- Configures DHCP:
  - Creates scope 10.0.1.100-10.0.1.200
  - Sets gateway: 10.0.1.1
  - Sets DNS: 10.0.1.10
  - Sets domain: lab.local
- Exports user credentials:
  - CSV file: `C:\LabBootstrap\users\created_users.csv`
  - ACL restricted to Administrators only
  - Includes: Username, Password, FirstName, LastName
- Output: `C:\LabBootstrap\logs\stage2.log`

**Key Features:**
- Idempotent: Won't recreate users if they exist
- Intelligent: Predefined name list for deterministic behavior
- Secure: Passwords never logged, file ACL restricted
- Robust: Detailed error handling, service readiness checks
- Self-cleaning: Removes Scheduled Task after successful completion

### Documentation Files

#### 7. **LAAB_README.md** (NEW)
Comprehensive 400+ line documentation covering:
- Overview and features
- Two-stage bootstrap explanation
- Prerequisites and setup instructions
- How to run (4-step guide)
- Verification procedures
- Idempotency explanation
- Network topology diagram
- Troubleshooting guide
- Advanced configuration options
- Security notes

#### 8. **terraform.tfvars.example** (NEW)
Example variables file with:
- All required and optional variables
- Helpful comments
- Default values
- Instructions for safe password generation

#### 9. **.gitignore** (NEW)
Git ignore rules:
- Terraform state files (*.tfstate, *.tfstate.backup)
- Variable files (*tfvars, except example)
- .terraform/ directory
- IDE and OS files
- Credentials and logs

## Architecture Overview

### Two-Stage Bootstrap Flow

```
terraform apply
    ↓
VM Creation
    ↓
CustomScriptExtension triggers
    ↓
Stage 1: 01-promote-dc.ps1 (5-8 min)
  - Install roles
  - Promote to DC
  - Schedule Stage 2
  - REBOOT
    ↓
Stage 2: 02-configure-lab.ps1 (3-5 min)
  - Wait for AD services
  - Create OUs
  - Create 30 users
  - Configure DHCP
  - Export user credentials
  - Cleanup Scheduled Task
    ↓
Lab Ready! (10-15 min total)
```

### Network Topology

```
Azure Subscription
├─ Resource Group: rg-ad-lab
├─ VNet: 10.0.0.0/16
│  └─ Subnet: 10.0.1.0/24
│     ├─ DC01 (10.0.1.10)
│     │  ├─ Private IP: 10.0.1.10
│     │  ├─ Domain Controller
│     │  ├─ DNS Server
│     │  └─ DHCP Server
│     └─ SRV01 (10.0.1.20)
│        ├─ Private IP: 10.0.1.20
│        ├─ Public IP: <auto-assigned>
│        └─ Lab workstation
├─ Network Security Group
│  ├─ RDP: 3389 (from your public IP)
│  ├─ WinRM: 5985-5986 (from Azure services)
│  ├─ DNS: 53/UDP (all internal)
│  ├─ Kerberos: 88/TCP (all internal)
│  └─ LDAP: 389/TCP (all internal)
└─ Public IP (SRV01 RDP access)
```

## Idempotency Implementation

### Stage 1 Safety Checks
- Checks if server is already a DC before promotion
- Skips promotion if already promoted
- Safely schedules Stage 2 with existence check

### Stage 2 Safety Checks
- Queries existing users before creating
- Skips users that already exist
- OUs checked and created with error handling
- DHCP scope won't error if it exists
- Scheduled Task cleanup prevents re-execution

### User Password Generation
- Deterministic first/last name list (same users every time)
- Pseudorandom passwords with secure generation
- Passwords stored securely in ACL-restricted CSV

## Security Features

1. **Credential Handling**
   - Admin password handled as Terraform sensitive variable
   - DSRM password passed securely to script
   - Passwords never logged or output
   - Secrets not stored in outputs

2. **File Permissions**
   - User CSV file: Administrators only (ACL-restricted)
   - Bootstrap directories: System permissions
   - Log files readable by Administrators

3. **Network Security**
   - RDP limited to user's public IP (auto-detected)
   - WinRM limited to Azure internal service tag
   - DNS/Kerberos/LDAP only within VNet

4. **Password Policy**
   - 14-character minimum
   - Mixed case + numbers + special characters
   - Lab users: Password never expires (lab convenience)

## Testing Checklist

- [ ] Terraform init succeeds
- [ ] Terraform plan shows expected resources (2 VMs, VNet, NSG, etc.)
- [ ] Terraform apply completes without errors
- [ ] Stage 1 log created: `C:\LabBootstrap\logs\stage1.log`
- [ ] Server reboots after DC promotion (monitor from Azure Portal)
- [ ] Stage 2 log created: `C:\LabBootstrap\logs\stage2.log`
- [ ] User CSV created: `C:\LabBootstrap\users\created_users.csv`
- [ ] Get-ADDomain returns lab.local
- [ ] Get-ADOrganizationalUnit returns 5 OUs
- [ ] Get-ADUser count equals 30
- [ ] Get-DhcpServerv4Scope shows configured scope
- [ ] RDP to SRV01 succeeds via public IP
- [ ] SRV01 can ping DC01 by name
- [ ] Rerunning terraform apply doesn't fail

## Known Limitations

1. **User Generation**
   - Limited to 30 users (predefined first/last name list)
   - Extend scripts/02-configure-lab.ps1 for more users

2. **Domain Name**
   - Currently single domain only
   - Trust relationships not configured

3. **Script Hosting**
   - Requires public GitHub repo for scripts
   - Alternative: Azure Storage with public access

4. **Networking**
   - Single subnet only
   - No site-to-site VPN or ExpressRoute

## Migration Path for Existing Users

If you have existing users in the domain, the scripts will:
1. Detect existing users in OU=Users
2. Skip recreating those users
3. Only create missing users up to the limit

This allows safe reruns without data loss.

## Future Enhancements

Possible additions (not implemented):
- [ ] Multi-domain forest setup
- [ ] Service Accounts OU with specific permissions
- [ ] Group Policy Objects (GPOs)
- [ ] Certificate Authority (PKI)
- [ ] Exchange or other workloads
- [ ] Ansible playbook for SRV01 domain join
- [ ] Monitoring/alerting integration
- [ ] Backup/restore procedures
- [ ] Disaster recovery planning

## Changelog

### v1.0 (Initial Release)
- Complete two-stage AD lab provisioning
- 30 auto-generated test users
- DHCP server configuration
- NSG with proper rules
- Comprehensive logging
- Idempotent scripts
- Full documentation

---

**Terraform Version**: 1.4.0+
**Azure Provider**: 3.0+
**PowerShell**: 5.0+ (Windows Server 2022)
**Total Setup Time**: 10-15 minutes
**Estimated Monthly Cost**: $40-60 USD (B2ms VMs @ $30-40/month each)
