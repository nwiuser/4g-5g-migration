# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = merge(
    var.tags,
    {
      Name = var.resource_group_name
    }
  )
}

# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = var.vnet_name
  address_space       = var.vnet_address_space
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = merge(
    var.tags,
    {
      Name = var.vnet_name
    }
  )
}

# Subnet for Core VM (EPC + eNodeB)
resource "azurerm_subnet" "core" {
  name                 = var.subnet_core_name
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_core_address_prefix]
}

# Subnet for UE VM
resource "azurerm_subnet" "ue" {
  name                 = var.subnet_ue_name
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_ue_address_prefix]
}

# Network Security Group for Core VM
resource "azurerm_network_security_group" "core_nsg" {
  name                = "srsran-core-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "AllowSSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowS1MME"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "36412"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowGTPU"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "2152"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowZMQRX"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "2001"
    source_address_prefix      = var.subnet_ue_address_prefix
    destination_address_prefix = "*"
  }

  tags = merge(
    var.tags,
    {
      Name = "srsran-core-nsg"
    }
  )
}

# Network Security Group for UE VM
resource "azurerm_network_security_group" "ue_nsg" {
  name                = "srsran-ue-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "AllowSSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowZMQTX"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "2000"
    source_address_prefix      = var.subnet_core_address_prefix
    destination_address_prefix = "*"
  }

  tags = merge(
    var.tags,
    {
      Name = "srsran-ue-nsg"
    }
  )
}

# Associate NSG with Core subnet
resource "azurerm_subnet_network_security_group_association" "core" {
  subnet_id                 = azurerm_subnet.core.id
  network_security_group_id = azurerm_network_security_group.core_nsg.id
}

# Associate NSG with UE subnet
resource "azurerm_subnet_network_security_group_association" "ue" {
  subnet_id                 = azurerm_subnet.ue.id
  network_security_group_id = azurerm_network_security_group.ue_nsg.id
}
