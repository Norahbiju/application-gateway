output "public_ip_address" {
  value = azurerm_public_ip.app_gateway.ip_address
}

output "application_gateway_id" {
  value = azurerm_application_gateway.this.id
}

output "backend_address_pool_ids" {
  value = {
    for pool in azurerm_application_gateway.this.backend_address_pool : trimprefix(pool.name, "pool-") => pool.id
  }
}
