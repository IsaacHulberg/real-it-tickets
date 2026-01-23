output "dc_private_ip" {
  value       = azurerm_network_interface.dc_nic.private_ip_address
  description = "DC01 private IP address"
}

output "dc_public_ip" {
  value       = azurerm_public_ip.dc_pip.ip_address
  description = "DC01 public IP for RDP access"
}

output "srv_private_ip" {
  value       = azurerm_network_interface.srv_nic.private_ip_address
  description = "SRV01 private IP address"
}

output "srv_public_ip" {
  value       = azurerm_public_ip.srv_pip.ip_address
  description = "SRV01 public IP for RDP access"
}

output "admin_username" {
  value       = var.admin_username
  description = "Admin username for VMs"
}

output "rdp_allowed_cidr" {
  value       = local.my_public_ip_cidr
  description = "Public IP (as /32) automatically allowed to RDP in via NSG."
}
