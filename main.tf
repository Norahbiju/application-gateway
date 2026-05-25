locals {
  apps = {
    organic = {
      display_name     = "organic"
      repo_url         = "https://github.com/Msocial123/organic-ghee.git"
      host_name        = "organic.nexaflow.site"
      app_port         = 5656
      mongodb_database = "restorent"
      start_command    = "node src/app.js"
      instance_count   = var.vmss_instance_count
    }

    fitness = {
      display_name     = "fitness"
      repo_url         = "https://github.com/Msocial123/Fitness_Tracker.git"
      host_name        = "fitness.nexaflow.site"
      app_port         = 5000
      mongodb_database = "fitness-tracker"
      start_command    = "npm start"
      instance_count   = var.vmss_instance_count
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

  project_name                        = var.project_name
  location                            = var.location
  resource_group_name                 = azurerm_resource_group.this.name
  hub_vnet_address_space              = var.hub_vnet_address_space
  application_gateway_subnet_prefixes = var.application_gateway_subnet_prefixes
  azure_firewall_subnet_prefixes      = var.azure_firewall_subnet_prefixes
  azure_bastion_subnet_prefixes       = var.azure_bastion_subnet_prefixes
  organic_vnet_address_space          = var.organic_vnet_address_space
  organic_subnet_prefixes             = var.organic_subnet_prefixes
  fitness_vnet_address_space          = var.fitness_vnet_address_space
  fitness_subnet_prefixes             = var.fitness_subnet_prefixes
  tags                                = var.tags
}

module "cosmosdb" {
  source = "./modules/cosmosdb"

  project_name        = var.project_name
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  database_names      = distinct([for app in local.apps : app.mongodb_database])
  spoke_vnet_ids      = module.network.spoke_vnet_ids
  spoke_subnet_ids    = module.network.spoke_subnet_ids
  tags                = var.tags
}

module "compute" {
  source = "./modules/compute"

  project_name                         = var.project_name
  location                             = var.location
  resource_group_name                  = azurerm_resource_group.this.name
  spoke_subnet_ids                     = module.network.spoke_subnet_ids
  application_gateway_backend_pool_ids = module.application_gateway.backend_address_pool_ids
  vm_size                              = var.vm_size
  admin_username                       = var.admin_username
  admin_auth = {
    type           = var.authentication_type
    password       = var.admin_password
    ssh_public_key = var.admin_ssh_public_key
  }
  apps                      = local.apps
  mongodb_connection_string = module.cosmosdb.mongodb_connection_string
  tags                      = var.tags
}

module "application_gateway" {
  source = "./modules/application_gateway"

  project_name          = var.project_name
  location              = var.location
  resource_group_name   = azurerm_resource_group.this.name
  app_gateway_subnet_id = module.network.application_gateway_subnet_id
  backend_targets = {
    for key, app in local.apps : key => {
      host_name    = app.host_name
      display_name = app.display_name
    }
  }
  tags = var.tags
}
