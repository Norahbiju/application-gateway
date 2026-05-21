variable "project_name" {
  description = "Short name used as a prefix for Azure resources."
  type        = string
  default     = "frontend-alb"
}

variable "location" {
  description = "Azure region for every resource."
  type        = string
  default     = "westus"
}

variable "admin_username" {
  description = "Linux administrator username for the backend VMs."
  type        = string
  default     = "azureuser"
}

variable "authentication_type" {
  description = "Authentication mode for backend VMs. Valid values are password or ssh_key."
  type        = string
  default     = "password"

  validation {
    condition     = contains(["password", "ssh_key"], var.authentication_type)
    error_message = "authentication_type must be either password or ssh_key."
  }
}

variable "admin_password" {
  description = "Linux administrator password for the backend VMs when authentication_type is password. Must satisfy Azure VM password complexity requirements."
  type        = string
  sensitive   = true
  default     = null

  validation {
    condition     = var.admin_password == null || length(var.admin_password) >= 12
    error_message = "admin_password must be null or at least 12 characters long."
  }

  validation {
    condition     = var.authentication_type != "password" || (var.admin_password != null && length(var.admin_password) >= 12)
    error_message = "Set admin_password to at least 12 characters when authentication_type is password."
  }
}

variable "admin_ssh_public_key" {
  description = "SSH public key authorized for the backend VMs when authentication_type is ssh_key."
  type        = string
  sensitive   = true
  default     = null

  validation {
    condition     = var.authentication_type != "ssh_key" || (var.admin_ssh_public_key != null && length(var.admin_ssh_public_key) > 0)
    error_message = "Set admin_ssh_public_key when authentication_type is ssh_key."
  }
}

variable "vm_size" {
  description = "VM size for backend VMs. Run scripts/write-vm-sku-auto-tfvars.ps1 to populate this from az vm list-skus in West US."
  type        = string
  default     = "Standard_B2s"
}

variable "vnet_address_space" {
  description = "Address space for the virtual network."
  type        = list(string)
  default     = ["10.20.0.0/16"]
}

variable "app_gateway_subnet_prefixes" {
  description = "Address prefixes for the Application Gateway subnet."
  type        = list(string)
  default     = ["10.20.1.0/24"]
}

variable "backend_subnet_prefixes" {
  description = "Address prefixes for the backend VMs subnet."
  type        = list(string)
  default     = ["10.20.2.0/24"]
}

variable "ssh_source_address_prefix" {
  description = "Optional source CIDR allowed to SSH to backend VMs. Leave null to disable inbound SSH."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to all supported resources."
  type        = map(string)
  default = {
    workload    = "frontend-alb"
    environment = "dev"
    managed_by  = "terraform"
  }
}
