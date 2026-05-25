locals {
  use_password_auth = var.admin_auth.type == "password"
  use_ssh_key_auth  = var.admin_auth.type == "ssh_key"
}

resource "azurerm_linux_virtual_machine_scale_set" "app" {
  for_each = var.apps

  name                            = "vmss-${var.project_name}-${each.key}"
  location                        = var.location
  resource_group_name             = var.resource_group_name
  sku                             = var.vm_size
  instances                       = each.value.instance_count
  admin_username                  = var.admin_username
  admin_password                  = local.use_password_auth ? var.admin_auth.password : null
  disable_password_authentication = local.use_ssh_key_auth
  upgrade_mode                    = "Manual"
  custom_data = base64encode(templatefile("${path.module}/cloud-init.tftpl", {
    app_name                  = each.value.display_name
    repo_url                  = each.value.repo_url
    host_name                 = each.value.host_name
    app_port                  = each.value.app_port
    mongodb_database          = each.value.mongodb_database
    mongodb_connection_string = var.mongodb_connection_string
    start_command             = each.value.start_command
  }))
  tags = var.tags

  dynamic "admin_ssh_key" {
    for_each = local.use_ssh_key_auth ? [var.admin_auth.ssh_public_key] : []

    content {
      username   = var.admin_username
      public_key = admin_ssh_key.value
    }
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  network_interface {
    name    = "nic-${each.key}"
    primary = true

    ip_configuration {
      name                                         = "ipconfig1"
      primary                                      = true
      subnet_id                                    = var.spoke_subnet_ids[each.key]
      application_gateway_backend_address_pool_ids = [var.application_gateway_backend_pool_ids[each.key]]
    }
  }
}
