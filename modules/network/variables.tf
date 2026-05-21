variable "project_name" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "vnet_address_space" {
  type    = list(string)
  default = ["10.20.0.0/16"]
}

variable "app_gateway_subnet_prefixes" {
  type    = list(string)
  default = ["10.20.1.0/24"]
}

variable "backend_subnet_prefixes" {
  type    = list(string)
  default = ["10.20.2.0/24"]
}

variable "ssh_source_address_prefix" {
  type    = string
  default = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
