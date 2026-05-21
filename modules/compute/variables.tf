variable "project_name" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "backend_subnet_id" {
  type = string
}

variable "vm_size" {
  type = string
}

variable "admin_username" {
  type = string
}

variable "admin_auth" {
  type = object({
    type           = string
    password       = optional(string)
    ssh_public_key = optional(string)
  })
  sensitive = true

  validation {
    condition     = contains(["password", "ssh_key"], var.admin_auth.type)
    error_message = "admin_auth.type must be either password or ssh_key."
  }

  validation {
    condition     = var.admin_auth.type != "password" || try(length(var.admin_auth.password), 0) >= 12
    error_message = "admin_auth.password is required and must be at least 12 characters when admin_auth.type is password."
  }

  validation {
    condition     = var.admin_auth.type != "ssh_key" || try(length(var.admin_auth.ssh_public_key), 0) > 0
    error_message = "admin_auth.ssh_public_key is required when admin_auth.type is ssh_key."
  }
}

variable "apps" {
  type = map(object({
    display_name     = string
    repo_url         = string
    host_name        = string
    app_port         = number
    mongodb_database = string
    start_command    = string
  }))
}

variable "tags" {
  type    = map(string)
  default = {}
}
