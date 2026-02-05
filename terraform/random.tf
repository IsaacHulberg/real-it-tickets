# Generate random passwords if not provided
resource "random_password" "admin_password" {
  length  = 16
  special = true
  override_special = "!@#$%^&*"
}

resource "random_password" "dsrm_password" {
  length  = 16
  special = true
  override_special = "!@#$%^&*"
}

# Use provided password or generated one
locals {
  admin_password = var.admin_password != "" ? var.admin_password : random_password.admin_password.result
  dsrm_password  = var.dsrm_password != "" ? var.dsrm_password : random_password.dsrm_password.result
}
