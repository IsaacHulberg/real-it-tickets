# Quick Start: AD Lab in 5 Minutes

## TL;DR - The Fast Path

### Prerequisites
- Azure subscription
- Terraform installed
- Azure CLI logged in: `az login`

### Step 1: Clone & Enter Directory
```bash
git clone https://github.com/YOUR-ORG/YOUR-REPO.git
cd terraform
```

### Step 2: Create terraform.tfvars
```bash
cat > terraform.tfvars << 'EOF'
admin_username = "azureuser"
admin_password = "MyP@ssw0rd123!"
dsrm_password  = "MyDsrmp@ssw0rd123!"
EOF
```

> **Important**: Use strong passwords with uppercase, lowercase, numbers, and special characters.

### Step 3: Deploy
```bash
terraform init
terraform apply
```

When prompted, type `yes` to confirm.

### Step 4: Wait 10-15 Minutes
The provisioning happens in two stages:
1. **Stage 1** (5-8 min): Install roles, promote to DC, reboot
2. **Stage 2** (3-5 min): Create OUs, users, configure DHCP

### Step 5: Get Connection Info
```bash
terraform output srv_public_ip
```

Use this IP to RDP to SRV01 with username `azureuser` and your password.

---

## Verify It Worked

Once deployed, RDP to the public IP:

```powershell
# On the DC, check:
Get-ADDomain
Get-ADUser -Filter * | Measure-Object
Get-DhcpServerv4Scope
```

Expected:
- Domain: `lab.local`
- User count: 30
- DHCP scope: Active

---

## Common Issues

| Problem | Solution |
|---------|----------|
| "subscription not found" | Run `az account set --subscription <id>` |
| Extension failed | Check Azure Portal > VM > Extensions > Status |
| Users not created | Wait 10 min. Check Stage 2 log: `C:\LabBootstrap\logs\stage2.log` |
| Can't RDP | Your public IP changed. Get new one: `terraform output rdp_allowed_cidr` |

---

## Cleanup
```bash
terraform destroy
```

Type `yes` to confirm deletion.

---

## Next Steps

- **Full Docs**: See `LAAB_README.md`
- **Implementation Details**: See `IMPLEMENTATION_SUMMARY.md`
- **Custom Domain**: `terraform apply -var="domain_name=corp.local"`
- **Larger VM**: `terraform apply -var="vm_size=Standard_B4ms"`

---

**Time to Lab**: 15 minutes from zero to fully configured Active Directory!

Need help? Check the logs or open an issue on GitHub.
