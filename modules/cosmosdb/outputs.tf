output "account_id" {
  value = azurerm_cosmosdb_account.this.id
}

output "account_name" {
  value = azurerm_cosmosdb_account.this.name
}

output "mongodb_connection_string" {
  value     = azurerm_cosmosdb_account.this.primary_mongodb_connection_string
  sensitive = true
}
