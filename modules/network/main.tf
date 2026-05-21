resource "azurerm_virtual_network" "this" {
  name                = "vnet-${var.project_name}-${var.location}"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.vnet_address_space
  tags                = var.tags
}

resource "azurerm_subnet" "app_gateway" {
  name                 = "snet-alb"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = var.app_gateway_subnet_prefixes
}

resource "azurerm_subnet" "backend" {
  name                 = "snet-backend"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = var.backend_subnet_prefixes
}

resource "azurerm_network_security_group" "backend" {
  name                = "nsg-${var.project_name}-backend"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  security_rule {
    name                       = "AllowHttpFromApplicationGatewaySubnet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = var.app_gateway_subnet_prefixes[0]
    destination_address_prefix = "*"
  }

  dynamic "security_rule" {
    for_each = var.ssh_source_address_prefix == null ? [] : [var.ssh_source_address_prefix]

    content {
      name                       = "AllowSshFromTrustedSource"
      priority                   = 110
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefix      = security_rule.value
      destination_address_prefix = "*"
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "backend" {
  subnet_id                 = azurerm_subnet.backend.id
  network_security_group_id = azurerm_network_security_group.backend.id
}

resource "azurerm_public_ip" "nat" {
  name                = "pip-${var.project_name}-nat"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_nat_gateway" "backend" {
  name                = "nat-${var.project_name}-backend"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = "Standard"
  tags                = var.tags
}

resource "azurerm_nat_gateway_public_ip_association" "backend" {
  nat_gateway_id       = azurerm_nat_gateway.backend.id
  public_ip_address_id = azurerm_public_ip.nat.id
}

resource "azurerm_subnet_nat_gateway_association" "backend" {
  subnet_id      = azurerm_subnet.backend.id
  nat_gateway_id = azurerm_nat_gateway.backend.id
}
