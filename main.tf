locals {
  apps = {
    organic = {
      display_name     = "organic"
      repo_url         = "https://github.com/Msocial123/organic-ghee.git"
      host_name        = "organic.nexaflow.site"
      app_port         = 5656
      mongodb_database = "restorent"
      start_command    = "node src/app.js"
    }

    fitness = {
      display_name     = "fitness"
      repo_url         = "https://github.com/Msocial123/Fitness_Tracker.git"
      host_name        = "fitness.nexaflow.site"
      app_port         = 5000
      mongodb_database = "fitness-tracker"
      start_command    = "npm start"
    }
  }
}

resource "azurerm_resource_group" "this" {
  name     = "rg-${var.project_name}-${var.location}"
  location = var.location
  tags     = var.tags
}

module "network" {
  source = "./modules/network"

  project_name                = var.project_name
  location                    = var.location
  resource_group_name         = azurerm_resource_group.this.name
  vnet_address_space          = var.vnet_address_space
  app_gateway_subnet_prefixes = var.app_gateway_subnet_prefixes
  backend_subnet_prefixes     = var.backend_subnet_prefixes
  ssh_source_address_prefix   = var.ssh_source_address_prefix
  tags                        = var.tags
}

module "compute" {
  source = "./modules/compute"

  project_name        = var.project_name
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  backend_subnet_id   = module.network.backend_subnet_id
  vm_size             = var.vm_size
  admin_username      = var.admin_username
  admin_auth = {
    type           = var.authentication_type
    password       = var.admin_password
    ssh_public_key = var.admin_ssh_public_key
  }
  apps = local.apps
  tags = var.tags
}

module "application_gateway" {
  source = "./modules/application_gateway"

  project_name          = var.project_name
  location              = var.location
  resource_group_name   = azurerm_resource_group.this.name
  app_gateway_subnet_id = module.network.app_gateway_subnet_id
  backend_targets       = module.compute.backend_targets
  tags                  = var.tags
}
