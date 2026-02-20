output "dc_private_ip" {
  value       = azurerm_network_interface.dc_nic.private_ip_address
  description = "DC01 private IP address"
}

output "admin_username" {
  value = var.admin_username
  description = "Administrator username for VMs"
}

output "admin_password" {
  value = local.admin_password
  sensitive = true
  description = "Administrator password (run 'terraform output admin_password' to view)"
}

output "dc_public_ip" {
  value       = azurerm_public_ip.dc_pip.ip_address
  description = "DC01 public IP for RDP access"
}

output "rdp_allowed_cidr" {
  value       = local.my_public_ip_cidr
  description = "Public IP (as /32) automatically allowed to RDP in via NSG."
}

output "setup_script_url" {
  value       = var.setup_script_url != "" ? var.setup_script_url : "Not configured"
  description = "URL of the setup PowerShell script being used"
}

output "configure_script_url" {
  value       = var.configure_script_url != "" ? var.configure_script_url : "Not configured"
  description = "URL of the post-DC-promotion configuration script being used"
}