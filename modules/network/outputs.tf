output "hub_vnet_id" {
  value = azurerm_virtual_network.hub.id
}

output "spoke_vnet_ids" {
  value = {
    for key, vnet in azurerm_virtual_network.spoke : key => vnet.id
  }
}

output "application_gateway_subnet_id" {
  value = azurerm_subnet.application_gateway.id
}

output "spoke_subnet_ids" {
  value = {
    for key, subnet in azurerm_subnet.spoke_app : key => subnet.id
  }
}

output "firewall_private_ip_address" {
  value = azurerm_firewall.hub.ip_configuration[0].private_ip_address
}

output "firewall_public_ip_address" {
  value = azurerm_public_ip.firewall.ip_address
}

output "bastion_public_ip_address" {
  value = azurerm_public_ip.bastion.ip_address
}
