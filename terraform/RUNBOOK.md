# Runbook

This runbook is prescriptive. Follow each step exactly.

## 1) Run Terraform (from your local machine)

1. Open **PowerShell** (normal, not admin).
2. Change to the Terraform folder:

```
cd "C:\Users\hulbe\Documents\github\real-it-tickets\terraform"
```

3. Initialize Terraform:

```
terraform init
```

4. Apply the infrastructure (type `yes` when prompted):

```
terraform apply
```

## 2) Run the lab configuration script (on the DC VM)

1. RDP into the **DC VM** (dc01).
2. Open **PowerShell as Administrator**:
   - Start menu → type `PowerShell`
   - Right‑click **Windows PowerShell**
   - Click **Run as administrator**
3. Run the script:
   - Click inside the PowerShell window
   - Type the command exactly as shown
   - Press **Enter**

```
C:\Users\Public\Desktop\LabScripts\02-configure-lab.ps1
```

## 3) Inject the ticket issue (on the DC VM)

1. In the **same elevated PowerShell** window, run:
   - Click inside the PowerShell window
   - Type the command exactly as shown
   - Press **Enter**

```
C:\Users\Public\Desktop\LabScripts\03-ticket-injection.ps1
```

That’s it. Do not run anything else unless instructed.
