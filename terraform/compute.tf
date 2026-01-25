# =========================
# Local Values
# =========================
locals {
  my_public_ip_cidr = "${data.http.my_public_ip.response_body}/32"
}

# =========================
# Data Sources
# =========================
data "http" "my_public_ip" {
  url = "https://ifconfig.me"
}

# =========================
# Resource Group
# =========================
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# =========================
# Virtual Network
# =========================
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-ad-lab"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

# =========================
# Subnet
# =========================
resource "azurerm_subnet" "subnet" {
  name                 = "subnet-ad-lab"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# =========================
# DC01 NIC
# =========================
# DC01 Public IP
# =========================
resource "azurerm_public_ip" "dc_pip" {
  name                = "pip-dc01"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# =========================
# DC01 NIC
# =========================
resource "azurerm_network_interface" "dc_nic" {
  name                = "dc-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.10"
    public_ip_address_id          = azurerm_public_ip.dc_pip.id
  }
}

# =========================
# DC01 VM
# =========================
resource "azurerm_windows_virtual_machine" "dc" {
  name                = "dc01"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = var.vm_size

  admin_username = var.admin_username
  admin_password = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.dc_nic.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }
}

# =========================
# DC01 Custom Script Extension
# =========================
# This extension downloads and runs PowerShell scripts from URLs
# The setup script handles DC promotion and schedules the configure script after reboot
# If setup_script_url is empty, the extension will not execute any scripts
resource "azurerm_virtual_machine_extension" "dc_custom_script" {
  name                 = "dc01-custom-script"
  virtual_machine_id   = azurerm_windows_virtual_machine.dc.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    fileUris = var.setup_script_url != "" ? compact([
      var.setup_script_url,
      var.configure_script_url != "" ? var.configure_script_url : "",
      var.adcreation_script_url != "" ? var.adcreation_script_url : ""
    ]) : []
  })

  protected_settings = jsonencode({
    commandToExecute = var.setup_script_url != "" ? "powershell.exe -ExecutionPolicy Bypass -NoProfile -Command \"$ErrorActionPreference='Stop'; $scriptName='${basename(var.setup_script_url)}'; Write-Host 'Downloaded script: $scriptName'; if (Test-Path $scriptName) { Write-Host 'Executing script: $scriptName'; & .\\$scriptName -DSRMPassword '${replace(var.dsrm_password, "'", "''")}' } else { Write-Error 'Script file not found: $scriptName'; exit 1 }\"" : "powershell.exe -ExecutionPolicy Bypass -Command \"Write-Host 'No setup script URL configured. Skipping automated setup.'\""
  })

  # Wait for VM to be ready before running script
  depends_on = [
    azurerm_windows_virtual_machine.dc
  ]

  lifecycle {
    ignore_changes = [
      settings,
      protected_settings
    ]
  }
}

# =========================
# SRV01 Public IP
# =========================
resource "azurerm_public_ip" "srv_pip" {
  name                = "pip-srv01"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# =========================
# SRV01 NIC
# =========================
resource "azurerm_network_interface" "srv_nic" {
  name                = "srv-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.20"
    public_ip_address_id          = azurerm_public_ip.srv_pip.id
  }
}

# =========================
# SRV01 VM
# =========================
resource "azurerm_windows_virtual_machine" "srv" {
  name                = "srv01"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = var.vm_size

  admin_username = var.admin_username
  admin_password = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.srv_nic.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }
}
