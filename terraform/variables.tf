variable "location" {
  default = "eastus"
}

variable "resource_group_name" {
  default = "rg-ad-lab"
}

variable "admin_username" {
  type        = string
  description = "Local admin username for VMs"
}

variable "admin_password" {
  type        = string
  sensitive   = true
  description = "Local admin password for VMs"
}

variable "vm_size" {
  default = "Standard_B2ms"
}