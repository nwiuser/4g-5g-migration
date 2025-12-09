# Network Interface for Core VM
resource "azurerm_network_interface" "core" {
  name                = "${var.core_vm_name}-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.core.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.10"
    public_ip_address_id          = azurerm_public_ip.core.id
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.core_vm_name}-nic"
    }
  )
}

# Network Interface for UE VM
resource "azurerm_network_interface" "ue" {
  name                = "${var.ue_vm_name}-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.ue.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.2.10"
    public_ip_address_id          = azurerm_public_ip.ue.id
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.ue_vm_name}-nic"
    }
  )
}

# Public IP for Core VM
resource "azurerm_public_ip" "core" {
  name                = "${var.core_vm_name}-pip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = merge(
    var.tags,
    {
      Name = "${var.core_vm_name}-pip"
    }
  )
}

# Public IP for UE VM
resource "azurerm_public_ip" "ue" {
  name                = "${var.ue_vm_name}-pip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = merge(
    var.tags,
    {
      Name = "${var.ue_vm_name}-pip"
    }
  )
}

# Core VM (EPC + eNodeB)
resource "azurerm_linux_virtual_machine" "core" {
  name                = var.core_vm_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  size                = var.vm_size

  admin_username = var.admin_username

  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = file("~/.ssh/id_rsa.pub")
  }

  network_interface_ids = [
    azurerm_network_interface.core.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = var.vm_image_publisher
    offer     = var.vm_image_offer
    sku       = var.vm_image_sku
    version   = var.vm_image_version
  }

  tags = merge(
    var.tags,
    {
      Name    = var.core_vm_name
      Purpose = "srsRAN Core (EPC + eNodeB)"
    }
  )

  depends_on = [
    azurerm_subnet_network_security_group_association.core
  ]
}

# UE VM
resource "azurerm_linux_virtual_machine" "ue" {
  name                = var.ue_vm_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  size                = var.vm_size

  admin_username = var.admin_username

  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = file("~/.ssh/id_rsa.pub")
  }

  network_interface_ids = [
    azurerm_network_interface.ue.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = var.vm_image_publisher
    offer     = var.vm_image_offer
    sku       = var.vm_image_sku
    version   = var.vm_image_version
  }

  tags = merge(
    var.tags,
    {
      Name    = var.ue_vm_name
      Purpose = "srsRAN User Equipment"
    }
  )

  depends_on = [
    azurerm_subnet_network_security_group_association.ue
  ]
}
