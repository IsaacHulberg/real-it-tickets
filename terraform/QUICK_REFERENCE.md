# AD Lab Deployment - Quick Reference Card

## 📋 Pre-Deployment Checklist

- [ ] Azure subscription active
- [ ] Terraform installed (`terraform version`)
- [ ] Azure CLI installed and authenticated (`az login`)
- [ ] Scripts pushed to GitHub (update fileUris in compute.tf)
- [ ] Strong passwords prepared (12+ chars, mixed case, numbers, special)

## 🚀 Deployment Commands

```bash
# Step 1: Navigate to terraform directory
cd terraform

# Step 2: Create variables file
cat > terraform.tfvars << EOF
admin_username = "azureuser"
admin_password = "YOUR_STRONG_PASSWORD_HERE"
dsrm_password  = "YOUR_DSRM_PASSWORD_HERE"
EOF

# Step 3: Initialize Terraform
terraform init

# Step 4: Review planned changes
terraform plan

# Step 5: Deploy (type 'yes' when prompted)
terraform apply

# Step 6: Wait 10-15 minutes for completion
```

## 📊 Timeline

| Phase | Duration | What Happens |
|-------|----------|--------------|
| VM Creation | 2-3 min | Azure creates 2 VMs and network |
| Stage 1 | 5-8 min | Install roles, promote to DC, **reboot** |
| Stage 2 | 3-5 min | Create OUs, users, configure DHCP |
| **Total** | **10-15 min** | Lab is ready! |

## 🔍 Verification Commands

```powershell
# Check Domain Created
Get-ADDomain

# Count Users (should be 30)
Get-ADUser -Filter * | Measure-Object

# List OUs (should be 5)
Get-ADOrganizationalUnit -Filter * | Format-Table Name

# Check DHCP Scope
Get-DhcpServerv4Scope

# View User Credentials
Import-Csv C:\LabBootstrap\users\created_users.csv | Format-Table
```

## 🌐 Access Information

```bash
# Get SRV01 Public IP for RDP
terraform output srv_public_ip

# Get your allowed RDP CIDR
terraform output rdp_allowed_cidr
```

**RDP Connection**
- Host: `<srv_public_ip>`
- Port: 3389
- Username: `azureuser`
- Password: `<admin_password>`

## 📁 Important Locations on DC

| Path | Purpose |
|------|---------|
| `C:\LabBootstrap\logs\stage1.log` | Bootstrap stage 1 log |
| `C:\LabBootstrap\logs\stage2.log` | Bootstrap stage 2 log |
| `C:\LabBootstrap\users\created_users.csv` | User credentials (Admins only) |

## 🚨 Troubleshooting Quick Fixes

| Issue | Solution |
|-------|----------|
| Extension failed | Verify fileUris in compute.tf point to GitHub |
| Users not created | Wait 15 min, check stage2.log |
| Can't RDP | Verify public IP matches rdp_allowed_cidr output |
| Reboot hung | RDP using public IP and manually restart |
| Forgot password | Check created_users.csv on DC |

## 🧹 Cleanup

```bash
# Destroy all resources
terraform destroy

# When prompted, type: yes
```

## 📚 Documentation Guide

- **QUICKSTART.md** - 5-minute overview
- **LAAB_README.md** - Complete reference (bookmark this!)
- **IMPLEMENTATION_SUMMARY.md** - Technical details
- **DELIVERY_SUMMARY.md** - What was delivered

## 🔐 Security Reminders

- [ ] **Don't commit** terraform.tfstate to Git
- [ ] **Protect** terraform.tfvars (contains passwords)
- [ ] **Rotate** admin passwords after deployment
- [ ] **Don't share** created_users.csv credentials
- [ ] **Update** fileUris before first deploy
- [ ] **Use VPN** for production deployments

## 📞 Support Resources

1. **Check Logs First**
   - Stage 1: `C:\LabBootstrap\logs\stage1.log`
   - Stage 2: `C:\LabBootstrap\logs\stage2.log`

2. **Azure Portal**
   - VM > Extensions + applications > Status
   - Check deployment logs for extension errors

3. **Documentation**
   - See LAAB_README.md Troubleshooting section
   - Search IMPLEMENTATION_SUMMARY.md for your issue

4. **Terraform**
   - Run `terraform plan` to see current state
   - Run `terraform state show <resource>` for details

## ⏱️ Performance Tips

- Use Standard_B4ms for larger environments: `-var="vm_size=Standard_B4ms"`
- Use Premium storage for better performance: Modify os_disk block
- Deploy during off-hours (faster quota availability)

## 🎯 Next Steps After Deployment

1. **Join SRV01 to Domain**
   ```powershell
   Add-Computer -DomainName lab.local -Credential (Get-Credential)
   Restart-Computer
   ```

2. **Create Group Policies** (optional)
   - Start > Group Policy Management

3. **Add Users to Groups** (optional)
   - Active Directory Users & Computers
   - OU=Users right-click on user > Properties

4. **Test DHCP** (optional)
   ```powershell
   # On a domain-joined VM
   ipconfig /release
   ipconfig /renew
   ```

## 💰 Cost Estimate

| Resource | Monthly Cost | Note |
|----------|----------|------|
| DC01 VM (B2ms) | $30-40 | Domain Controller |
| SRV01 VM (B2ms) | $30-40 | Workstation |
| Public IP | $5-10 | Static IP for RDP |
| Storage | $1-2 | OS disks |
| **Total** | **$70-85** | Approximate monthly |

*Costs vary by region - eastus is typically lowest cost*

---

## 🎓 Learning Resources

- **Active Directory Basics**: Microsoft Docs - AD DS Overview
- **PowerShell AD**: Microsoft Docs - ActiveDirectory Module
- **DHCP Configuration**: Microsoft Docs - DHCP Administration
- **Terraform Best Practices**: Terraform.io - Best Practices

---

**Keep this card handy! 📌**

Print or screenshot for quick reference during deployment.

Last Updated: January 2026
