output "vnet_id" {
  value = azurerm_virtual_network.this.id
}

output "app_gateway_subnet_id" {
  value = azurerm_subnet.app_gateway.id
}

output "backend_subnet_id" {
  value = azurerm_subnet.backend.id
}
