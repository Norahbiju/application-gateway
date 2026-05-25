variable "project_name" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "hub_vnet_address_space" {
  type    = list(string)
  default = ["10.20.0.0/16"]
}

variable "application_gateway_subnet_prefixes" {
  type    = list(string)
  default = ["10.20.1.0/24"]
}

variable "azure_firewall_subnet_prefixes" {
  type    = list(string)
  default = ["10.20.2.0/26"]
}

variable "azure_bastion_subnet_prefixes" {
  type    = list(string)
  default = ["10.20.3.0/26"]
}

variable "organic_vnet_address_space" {
  type    = list(string)
  default = ["10.21.0.0/16"]
}

variable "organic_subnet_prefixes" {
  type    = list(string)
  default = ["10.21.1.0/24"]
}

variable "fitness_vnet_address_space" {
  type    = list(string)
  default = ["10.22.0.0/16"]
}

variable "fitness_subnet_prefixes" {
  type    = list(string)
  default = ["10.22.1.0/24"]
}

variable "tags" {
  type    = map(string)
  default = {}
}
