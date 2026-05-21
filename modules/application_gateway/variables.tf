variable "project_name" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "app_gateway_subnet_id" {
  type = string
}

variable "backend_targets" {
  type = map(object({
    private_ip   = string
    host_name    = string
    display_name = string
  }))
}

variable "tags" {
  type    = map(string)
  default = {}
}
