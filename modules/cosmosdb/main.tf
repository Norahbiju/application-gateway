resource "azurerm_cosmosdb_account" "this" {
  name                          = "cosmos-${var.project_name}-${var.location}"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  offer_type                    = "Standard"
  kind                          = "MongoDB"
  mongo_server_version          = "7.0"
  public_network_access_enabled = false
  tags                          = var.tags

  capabilities {
    name = "EnableMongo"
  }

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = var.location
    failover_priority = 0
  }
}

resource "azurerm_cosmosdb_mongo_database" "app" {
  for_each = toset(var.database_names)

  name                = each.value
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.this.name
}

resource "azurerm_private_dns_zone" "mongo" {
  name                = "privatelink.mongo.cosmos.azure.com"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "spoke" {
  for_each = var.spoke_vnet_ids

  name                  = "pdns-${each.key}-mongo"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.mongo.name
  virtual_network_id    = each.value
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_endpoint" "mongo" {
  for_each = var.spoke_subnet_ids

  name                = "pe-${var.project_name}-${each.key}-mongo"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = each.value
  tags                = var.tags

  private_service_connection {
    name                           = "psc-${each.key}-mongo"
    private_connection_resource_id = azurerm_cosmosdb_account.this.id
    subresource_names              = ["MongoDB"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "mongo-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.mongo.id]
  }
}
