output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "resource_group_id" {
  description = "ID of the resource group"
  value       = azurerm_resource_group.main.id
}

output "vnet_id" {
  description = "ID of the Virtual Network"
  value       = azurerm_virtual_network.main.id
}

output "vnet_name" {
  description = "Name of the Virtual Network"
  value       = azurerm_virtual_network.main.name
}

output "core_vm_name" {
  description = "Name of the Core VM"
  value       = azurerm_linux_virtual_machine.core.name
}

output "core_vm_id" {
  description = "ID of the Core VM"
  value       = azurerm_linux_virtual_machine.core.id
}

output "core_vm_private_ip" {
  description = "Private IP address of the Core VM"
  value       = azurerm_network_interface.core.private_ip_address
}

output "core_vm_public_ip" {
  description = "Public IP address of the Core VM"
  value       = azurerm_public_ip.core.ip_address
}

output "ue_vm_name" {
  description = "Name of the UE VM"
  value       = azurerm_linux_virtual_machine.ue.name
}

output "ue_vm_id" {
  description = "ID of the UE VM"
  value       = azurerm_linux_virtual_machine.ue.id
}

output "ue_vm_private_ip" {
  description = "Private IP address of the UE VM"
  value       = azurerm_network_interface.ue.private_ip_address
}

output "ue_vm_public_ip" {
  description = "Public IP address of the UE VM"
  value       = azurerm_public_ip.ue.ip_address
}

output "core_nsg_name" {
  description = "Name of the Core VM Network Security Group"
  value       = azurerm_network_security_group.core_nsg.name
}

output "ue_nsg_name" {
  description = "Name of the UE VM Network Security Group"
  value       = azurerm_network_security_group.ue_nsg.name
}

output "ssh_connection_core" {
  description = "SSH connection command for Core VM"
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.core.ip_address}"
  sensitive   = true
}

output "ssh_connection_ue" {
  description = "SSH connection command for UE VM"
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.ue.ip_address}"
  sensitive   = true
}
