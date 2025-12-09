# Azure Provider Variables
variable "azure_subscription_id" {
  description = "Azure Subscription ID"
  type        = string
  sensitive   = true
}

variable "azure_tenant_id" {
  description = "Azure Tenant ID"
  type        = string
  sensitive   = true
}

variable "azure_client_id" {
  description = "Azure Service Principal Client ID"
  type        = string
  sensitive   = true
}

variable "azure_client_secret" {
  description = "Azure Service Principal Client Secret"
  type        = string
  sensitive   = true
}

# Infrastructure Variables
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-srsran-4g"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "francecentral"

  validation {
    condition     = contains(["norwayeast", "switzerlandnorth", "italynorth", "francecentral", "spaincentral"], var.location)
    error_message = "Location must be in allowed Azure regions due to subscription policy."
  }
}

variable "vnet_name" {
  description = "Virtual Network name"
  type        = string
  default     = "srsran-vnet"
}

variable "vnet_address_space" {
  description = "Address space for VNet"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "subnet_core_name" {
  description = "Subnet name for Core VM (EPC + eNodeB)"
  type        = string
  default     = "subnet-core"
}

variable "subnet_core_address_prefix" {
  description = "Address prefix for Core subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "subnet_ue_name" {
  description = "Subnet name for UE VM"
  type        = string
  default     = "subnet-ue"
}

variable "subnet_ue_address_prefix" {
  description = "Address prefix for UE subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "core_vm_name" {
  description = "Name of the Core VM (EPC + eNodeB)"
  type        = string
  default     = "srsran-core-vm"
}

variable "ue_vm_name" {
  description = "Name of the UE VM"
  type        = string
  default     = "srsran-ue-vm"
}

variable "vm_size" {
  description = "VM size for srsRAN VMs"
  type        = string
  default     = "Standard_B2s"
}

variable "vm_image_publisher" {
  description = "VM image publisher"
  type        = string
  default     = "debian"
}

variable "vm_image_offer" {
  description = "VM image offer"
  type        = string
  default     = "debian-11"
}

variable "vm_image_sku" {
  description = "VM image SKU"
  type        = string
  default     = "11-gen2"
}

variable "vm_image_version" {
  description = "VM image version"
  type        = string
  default     = "latest"
}

variable "admin_username" {
  description = "Admin username for VMs"
  type        = string
  default     = "azureuser"
  sensitive   = true
}

variable "ssh_public_key" {
  description = "SSH public key for VM authentication"
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project     = "srsRAN"
    Environment = "4G/5G Migration"
    ManagedBy   = "Terraform"
  }
}
