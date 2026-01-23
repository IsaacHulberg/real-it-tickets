# =========================
# Network Security Group
# =========================
resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-ad-lab"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "AllowRDP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowWinRM"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5985-5986"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowDNS"
    priority                   = 102
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "53"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowKerberos"
    priority                   = 103
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "88"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowLDAP"
    priority                   = 104
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    Environment = "Lab"
    Purpose     = "AD Lab"
  }
}
# Attach the NSG to the DC01 NIC
resource "azurerm_network_interface_security_group_association" "dc_nic_nsg" {
  network_interface_id      = azurerm_network_interface.dc_nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Attach the NSG to the SRV01 NIC
resource "azurerm_network_interface_security_group_association" "srv_nic_nsg" {
  network_interface_id      = azurerm_network_interface.srv_nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}
# =========================
# Additional Security Group Rules
# =========================
resource "azurerm_network_security_rule" "allow_winrm" {
  name                        = "AllowWinRMFromAzure"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5985-5986"
  source_address_prefix       = "AzureCloud"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}
