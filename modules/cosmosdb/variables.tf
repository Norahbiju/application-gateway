variable "project_name" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "database_names" {
  type = list(string)
}

variable "spoke_vnet_ids" {
  type = map(string)
}

variable "spoke_subnet_ids" {
  type = map(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}
