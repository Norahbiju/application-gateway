locals {
  spokes = {
    organic = {
      vnet_address_space = var.organic_vnet_address_space
      subnet_prefixes    = var.organic_subnet_prefixes
    }

    fitness = {
      vnet_address_space = var.fitness_vnet_address_space
      subnet_prefixes    = var.fitness_subnet_prefixes
    }
  }
}

resource "azurerm_virtual_network" "hub" {
  name                = "vnet-${var.project_name}-hub-${var.location}"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.hub_vnet_address_space
  tags                = var.tags
}

resource "azurerm_subnet" "application_gateway" {
  name                 = "ApplicationGatewaySubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = var.application_gateway_subnet_prefixes
}

resource "azurerm_subnet" "azure_firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = var.azure_firewall_subnet_prefixes
}

resource "azurerm_subnet" "azure_bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = var.azure_bastion_subnet_prefixes
}

resource "azurerm_virtual_network" "spoke" {
  for_each = local.spokes

  name                = "vnet-${var.project_name}-${each.key}-${var.location}"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = each.value.vnet_address_space
  tags                = var.tags
}

resource "azurerm_subnet" "spoke_app" {
  for_each = local.spokes

  name                              = "snet-${each.key}-app"
  resource_group_name               = var.resource_group_name
  virtual_network_name              = azurerm_virtual_network.spoke[each.key].name
  address_prefixes                  = each.value.subnet_prefixes
  private_endpoint_network_policies = "Disabled"
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  for_each = local.spokes

  name                         = "peer-hub-to-${each.key}"
  resource_group_name          = var.resource_group_name
  virtual_network_name         = azurerm_virtual_network.hub.name
  remote_virtual_network_id    = azurerm_virtual_network.spoke[each.key].id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  for_each = local.spokes

  name                         = "peer-${each.key}-to-hub"
  resource_group_name          = var.resource_group_name
  virtual_network_name         = azurerm_virtual_network.spoke[each.key].name
  remote_virtual_network_id    = azurerm_virtual_network.hub.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_public_ip" "firewall" {
  name                = "pip-${var.project_name}-firewall"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_firewall" "hub" {
  name                = "afw-${var.project_name}-hub"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  tags                = var.tags

  ip_configuration {
    name                 = "firewall-ipconfig"
    subnet_id            = azurerm_subnet.azure_firewall.id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }
}

resource "azurerm_firewall_network_rule_collection" "allow_outbound" {
  name                = "AllowSpokeOutbound"
  azure_firewall_name = azurerm_firewall.hub.name
  resource_group_name = var.resource_group_name
  priority            = 100
  action              = "Allow"

  rule {
    name                  = "AllowInternet"
    source_addresses      = concat(var.organic_subnet_prefixes, var.fitness_subnet_prefixes)
    destination_ports     = ["80", "443", "123"]
    destination_addresses = ["*"]
    protocols             = ["TCP", "UDP"]
  }
}

resource "azurerm_firewall_network_rule_collection" "allow_spoke_cosmos_private_endpoint" {
  name                = "AllowSpokeCosmosPrivateEndpoint"
  azure_firewall_name = azurerm_firewall.hub.name
  resource_group_name = var.resource_group_name
  priority            = 110
  action              = "Allow"

  rule {
    name                  = "AllowMongoPrivateEndpoint"
    source_addresses      = concat(var.organic_subnet_prefixes, var.fitness_subnet_prefixes)
    destination_ports     = ["10255"]
    destination_addresses = concat(var.organic_subnet_prefixes, var.fitness_subnet_prefixes)
    protocols             = ["TCP"]
  }
}

resource "azurerm_route_table" "spoke" {
  for_each = local.spokes

  name                          = "rt-${var.project_name}-${each.key}-egress"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  bgp_route_propagation_enabled = false
  tags                          = var.tags

  route {
    name                   = "DefaultToAzureFirewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.hub.ip_configuration[0].private_ip_address
  }

  dynamic "route" {
    for_each = each.key == "organic" ? var.fitness_vnet_address_space : var.organic_vnet_address_space

    content {
      name                   = "RouteToOtherSpokeViaAzureFirewall"
      address_prefix         = route.value
      next_hop_type          = "VirtualAppliance"
      next_hop_in_ip_address = azurerm_firewall.hub.ip_configuration[0].private_ip_address
    }
  }
}

resource "azurerm_subnet_route_table_association" "spoke" {
  for_each = local.spokes

  subnet_id      = azurerm_subnet.spoke_app[each.key].id
  route_table_id = azurerm_route_table.spoke[each.key].id
}

resource "azurerm_network_security_group" "spoke" {
  for_each = local.spokes

  name                = "nsg-${var.project_name}-${each.key}-app"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  security_rule {
    name                       = "AllowHttpFromHubApplicationGatewaySubnet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = var.application_gateway_subnet_prefixes[0]
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowVnetPrivateEndpointTraffic"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }
}

resource "azurerm_subnet_network_security_group_association" "spoke" {
  for_each = local.spokes

  subnet_id                 = azurerm_subnet.spoke_app[each.key].id
  network_security_group_id = azurerm_network_security_group.spoke[each.key].id
}

resource "azurerm_public_ip" "bastion" {
  name                = "pip-${var.project_name}-bastion"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_bastion_host" "hub" {
  name                = "bas-${var.project_name}-hub"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Basic"
  tags                = var.tags

  ip_configuration {
    name                 = "bastion-ipconfig"
    subnet_id            = azurerm_subnet.azure_bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
}
