# 🏛️ AD Lab Automation - Terraform Project Index

Welcome! You have a fully automated Active Directory lab provisioning system.

## 🚀 Quick Start (Choose Your Path)

### ⚡ **I'm in a hurry** (5 minutes)
→ Read: **[QUICKSTART.md](QUICKSTART.md)**

### 📖 **I want full understanding** (30 minutes)
→ Read: **[LAAB_README.md](LAAB_README.md)**

### 📋 **I need a reference card** (2 minutes)
→ Use: **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)**

### 🔧 **I need technical details** (15 minutes)
→ Read: **[IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md)**

### 📊 **I need project overview** (10 minutes)
→ Read: **[DELIVERY_SUMMARY.md](DELIVERY_SUMMARY.md)**

### ✅ **Final checklist & details** (5 minutes)
→ Read: **[FINAL_DELIVERY.md](FINAL_DELIVERY.md)**

---

## 📁 Project Structure

```
terraform/
├── 📄 Core Terraform Files
│   ├── compute.tf              [MODIFIED] VM & extension
│   ├── subnet-nsg.tf           [MODIFIED] NSG with WinRM rule
│   ├── variables.tf            [MODIFIED] AD variables
│   ├── outputs.tf              [MODIFIED] Enhanced outputs
│   ├── providers.tf            [UNCHANGED]
│   └── network.tf              [UNCHANGED]
│
├── 📂 scripts/                 [NEW] Bootstrap scripts
│   ├── 01-promote-dc.ps1      [NEW] Stage 1 (230 lines)
│   └── 02-configure-lab.ps1   [NEW] Stage 2 (350 lines)
│
├── 📚 Documentation            [NEW] Comprehensive guides
│   ├── QUICKSTART.md           [NEW] 5-minute overview
│   ├── LAAB_README.md          [NEW] 500-line complete guide
│   ├── IMPLEMENTATION_SUMMARY  [NEW] Technical deep-dive
│   ├── DELIVERY_SUMMARY.md     [NEW] Project summary
│   ├── QUICK_REFERENCE.md      [NEW] Cheat sheet
│   ├── FINAL_DELIVERY.md       [NEW] Detailed delivery report
│   └── README.md               [THIS FILE]
│
├── 📋 Configuration Examples   [NEW] Templates
│   └── terraform.tfvars.example
│
└── .gitignore                  [NEW] Security
```

---

## 🎯 What This Does

### One-Command Lab Setup
Run `terraform apply` and get:

✅ **Complete Active Directory Lab in 10-15 minutes**
- Domain Controller (DC01) at 10.0.1.10
- Test workstation (SRV01) at 10.0.1.20 with public IP
- 30 pre-generated test users with credentials
- DHCP server with configured scope
- DNS server integrated with AD
- Proper network segmentation and security

### Two-Stage Automated Bootstrap
1. **Stage 1** (5-8 min): Install roles, promote to DC
2. **Stage 2** (3-5 min): Create OUs, users, configure DHCP
3. Auto-recovery from reboot between stages

---

## ⚡ 60-Second Deployment

```bash
# 1. Set credentials
export TF_VAR_admin_username="azureuser"
export TF_VAR_admin_password="StrongP@ss123!"
export TF_VAR_dsrm_password="StrongDsrm@Pass123!"

# 2. Deploy
terraform init
terraform apply -auto-approve

# 3. Wait 10-15 minutes
# 4. Get access info
terraform output srv_public_ip
```

Then RDP to that public IP!

---

## 📖 Documentation by Purpose

| Goal | Read This | Time |
|------|-----------|------|
| **Get started immediately** | QUICKSTART.md | 5 min |
| **Deploy for real** | LAAB_README.md | 30 min |
| **Quick reference during deploy** | QUICK_REFERENCE.md | 2 min |
| **Understand architecture** | IMPLEMENTATION_SUMMARY.md | 20 min |
| **See what was delivered** | DELIVERY_SUMMARY.md | 10 min |
| **Deep technical details** | FINAL_DELIVERY.md | 15 min |

---

## 🔐 Security First

### Before You Deploy
- [ ] Update GitHub script URIs in `compute.tf`
- [ ] Create strong passwords (12+ chars, mixed case)
- [ ] Plan to NOT commit `terraform.tfstate`
- [ ] Plan to NOT commit `terraform.tfvars`

### After You Deploy
- [ ] Protect the user credentials CSV
- [ ] Rotate passwords as needed
- [ ] Configure Azure backups
- [ ] Review security logs

---

## 🚀 Getting Started

### Absolute Minimum (5 minutes)
```bash
# 1. Create variables
echo 'admin_username = "azureuser"' > terraform.tfvars
echo 'admin_password = "YOUR_PASSWORD"' >> terraform.tfvars
echo 'dsrm_password = "YOUR_DSRM_PASSWORD"' >> terraform.tfvars

# 2. Deploy
terraform init
terraform apply

# 3. Wait...
```

### Proper Way (with understanding)
1. **Read**: QUICKSTART.md (5 min)
2. **Prepare**: Create terraform.tfvars with strong passwords
3. **Update**: GitHub URIs in compute.tf
4. **Deploy**: terraform apply
5. **Wait**: 10-15 minutes
6. **Verify**: Check logs in C:\LabBootstrap\logs\

---

## ✅ Verify Success

Once deployed (wait 15 minutes):

```powershell
# These should work:
Get-ADDomain                    # Shows lab.local
Get-ADUser -Filter * | Measure  # Shows 30 users
Get-DhcpServerv4Scope          # Shows active scope
Get-DnsServerZone              # Shows lab.local zone
```

---

## 🎓 Key Concepts

### Two-Stage Bootstrap
Why two stages? DC promotion requires reboot. Stage 1 promotes and schedules Stage 2 to run automatically after reboot.

### Idempotency
Scripts check for existing resources and skip creation. Safe to run `terraform apply` multiple times.

### Deterministic Users
Same 30 first/last names every time (reproducible), random passwords (secure).

### Auto-IP Detection
Your public IP is detected and used to limit RDP access (secure by default).

---

## 📊 What Gets Created

| Resource | Type | Cost/Month |
|----------|------|-----------|
| DC01 VM | Standard_B2ms | $30-40 |
| SRV01 VM | Standard_B2ms | $30-40 |
| Public IP | Static | $5-10 |
| VNet + NSG | Networking | Free |
| **Total** | | **$70-85** |

---

## ⏱️ Timeline

- **0-2 min**: Resource creation
- **2-8 min**: Stage 1 (role installation, DC promotion)
- **8-9 min**: Automatic reboot
- **9-13 min**: Stage 2 (OUs, users, DHCP)
- **13-15 min**: Final checks and cleanup
- **15+ min**: Lab ready!

---

## 🆘 Troubleshooting Quick Links

| Problem | Solution |
|---------|----------|
| **Can't RDP** | Check `terraform output rdp_allowed_cidr` |
| **Users not created** | Wait 15 min, check Stage 2 log |
| **Extension failed** | Verify GitHub URIs in compute.tf |
| **DHCP not working** | Restart DHCP service, verify scope |

Full troubleshooting: See **LAAB_README.md** Troubleshooting section

---

## 🔧 Customization Examples

```bash
# Custom domain name
terraform apply -var="domain_name=corp.local"

# Larger VM
terraform apply -var="vm_size=Standard_B4ms"

# Custom DHCP range
terraform apply \
  -var="dhcp_scope_start=10.0.1.50" \
  -var="dhcp_scope_end=10.0.1.150"
```

---

## 🎓 Learning Path

1. **Start**: Read QUICKSTART.md (5 min)
2. **Deploy**: Follow steps (15 min)
3. **Understand**: Read LAAB_README.md (30 min)
4. **Deep Dive**: Read IMPLEMENTATION_SUMMARY.md (20 min)
5. **Explore**: Review PowerShell scripts (30 min)

---

## 📞 Support Resources

- **Logs**: Check `C:\LabBootstrap\logs\` on DC01
- **Portal**: Azure Portal → VM → Extensions
- **Docs**: All documentation in this directory
- **Scripts**: Located in `scripts/` folder

---

## 💡 Pro Tips

1. **Use QUICK_REFERENCE.md** during deployment
2. **Monitor Azure Portal** for progress
3. **Save user credentials CSV** in secure location
4. **Snapshot VMs** after successful deployment
5. **Test domain join** on SRV01 to verify
6. **Use terraform state** only locally (use remote state for production)

---

## 🎉 Success!

If you can:
- ✅ terraform apply completes
- ✅ VMs are created and running
- ✅ Get-ADDomain returns lab.local
- ✅ RDP to SRV01 works

**You're good to go!** Your AD lab is ready.

---

## 🚀 Next Steps

1. **Verify**: Run checks from LAAB_README.md
2. **Explore**: Browse OUs and users in Active Directory
3. **Test**: Join SRV01 to domain
4. **Customize**: Add groups, policies, or more users
5. **Extend**: Use as base for further testing

---

## 📚 All Documentation

| Document | Purpose | Length |
|----------|---------|--------|
| QUICKSTART.md | 5-minute overview | 50 lines |
| QUICK_REFERENCE.md | Cheat sheet | 200 lines |
| LAAB_README.md | Complete reference | 500 lines |
| IMPLEMENTATION_SUMMARY.md | Technical details | 400 lines |
| DELIVERY_SUMMARY.md | Project summary | 350 lines |
| FINAL_DELIVERY.md | Detailed report | 600 lines |

**Total**: 2,100+ lines of documentation!

---

## ✨ What You Got

✅ Complete Terraform IaC  
✅ Two-stage bootstrap scripts  
✅ Comprehensive documentation  
✅ Security best practices  
✅ Example configurations  
✅ Troubleshooting guides  
✅ Cost estimates  
✅ Deployment timelines  

**Everything** needed to deploy a production-quality AD lab.

---

## 🎯 Ready?

1. **Quick path**: Read [QUICKSTART.md](QUICKSTART.md) → Deploy
2. **Full path**: Read [LAAB_README.md](LAAB_README.md) → Deploy
3. **Reference**: Use [QUICK_REFERENCE.md](QUICK_REFERENCE.md) during deploy

---

**Your AD lab awaits. Deploy with confidence!** 🚀

---

*Last Updated: January 20, 2026*  
*Status: Production Ready ✅*  
*Estimated Setup Time: 15 minutes*
