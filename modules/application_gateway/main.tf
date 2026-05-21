resource "azurerm_public_ip" "app_gateway" {
  name                = "pip-${var.project_name}-agw"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_web_application_firewall_policy" "this" {
  name                = "waf-${var.project_name}-agw"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  policy_settings {
    enabled                     = true
    mode                        = "Prevention"
    request_body_check          = true
    file_upload_limit_in_mb     = 100
    max_request_body_size_in_kb = 128
  }

  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.2"
    }
  }
}

resource "azurerm_application_gateway" "this" {
  name                = "agw-${var.project_name}-waf"
  location            = var.location
  resource_group_name = var.resource_group_name
  firewall_policy_id  = azurerm_web_application_firewall_policy.this.id
  tags                = var.tags

  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "gateway-ip-config"
    subnet_id = var.app_gateway_subnet_id
  }

  frontend_ip_configuration {
    name                 = "public-frontend-ip"
    public_ip_address_id = azurerm_public_ip.app_gateway.id
  }

  frontend_port {
    name = "http-80"
    port = 80
  }

  dynamic "http_listener" {
    for_each = var.backend_targets

    content {
      name                           = "http-listener-${http_listener.key}"
      frontend_ip_configuration_name = "public-frontend-ip"
      frontend_port_name             = "http-80"
      protocol                       = "Http"
      host_name                      = http_listener.value.host_name
    }
  }

  dynamic "backend_address_pool" {
    for_each = var.backend_targets

    content {
      name         = "pool-${backend_address_pool.key}"
      ip_addresses = [backend_address_pool.value.private_ip]
    }
  }

  dynamic "probe" {
    for_each = var.backend_targets

    content {
      name                                      = "probe-${probe.key}"
      protocol                                  = "Http"
      path                                      = "/healthz"
      host                                      = "127.0.0.1"
      interval                                  = 30
      timeout                                   = 30
      unhealthy_threshold                       = 3
      pick_host_name_from_backend_http_settings = false

      match {
        status_code = ["200-399"]
      }
    }
  }

  dynamic "backend_http_settings" {
    for_each = var.backend_targets

    content {
      name                  = "http-settings-${backend_http_settings.key}"
      cookie_based_affinity = "Disabled"
      path                  = "/"
      port                  = 80
      protocol              = "Http"
      request_timeout       = 30
      probe_name            = "probe-${backend_http_settings.key}"
    }
  }

  dynamic "request_routing_rule" {
    for_each = var.backend_targets

    content {
      name                       = "host-routing-${request_routing_rule.key}"
      rule_type                  = "Basic"
      http_listener_name         = "http-listener-${request_routing_rule.key}"
      backend_address_pool_name  = "pool-${request_routing_rule.key}"
      backend_http_settings_name = "http-settings-${request_routing_rule.key}"
      priority                   = 100 + index(sort(keys(var.backend_targets)), request_routing_rule.key)
    }
  }
}
