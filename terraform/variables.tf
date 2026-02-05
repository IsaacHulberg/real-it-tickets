variable "location" {
  default = "eastus"
}

variable "resource_group_name" {
  default = "rg-ad-lab"
}

variable "admin_username" {
  type        = string
  description = "Local admin username for VMs"
  default     = "tempadmin"
}

variable "admin_password" {
  type        = string
  sensitive   = true
  description = "Local admin password for VMs (leave empty to auto-generate)"
  default     = ""
}

variable "vm_size" {
  default = "Standard_B2ms"
}

variable "setup_script_url" {
  type        = string
  description = "URL to download the main setup PowerShell script (e.g., from GitHub raw or Azure Storage)"
  default     = ""
}

variable "configure_script_url" {
  type        = string
  description = "URL to download the post-DC-promotion configuration script (e.g., from GitHub raw or Azure Storage)"
  default     = ""
}

variable "adcreation_script_url" {
  type        = string
  description = "URL to download the branch OU creation script (adcreation.ps1). If empty, Setup-AD-Lab.ps1 will look for it in the same directory."
  default     = ""
}

variable "domain_name" {
  type        = string
  description = "Active Directory domain name"
  default     = "lab.local"
}

variable "dsrm_password" {
  type        = string
  sensitive   = true
  description = "Directory Services Restore Mode password for domain controller"
  default     = "Temppassword123!@#"
}