resource "azurerm_network_interface" "app" {
  for_each = var.apps

  name                = "nic-${var.project_name}-${each.key}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = var.backend_subnet_id
    private_ip_address_allocation = "Dynamic"
  }
}

locals {
  use_password_auth = var.admin_auth.type == "password"
  use_ssh_key_auth  = var.admin_auth.type == "ssh_key"
}

resource "azurerm_linux_virtual_machine" "app" {
  for_each = var.apps

  name                = "vm-${var.project_name}-${each.key}"
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = var.vm_size
  admin_username      = var.admin_username
  admin_password      = local.use_password_auth ? var.admin_auth.password : null
  tags                = var.tags

  disable_password_authentication = local.use_ssh_key_auth
  network_interface_ids           = [azurerm_network_interface.app[each.key].id]
  custom_data = base64encode(templatefile("${path.module}/cloud-init.tftpl", {
    app_name         = each.value.display_name
    repo_url         = each.value.repo_url
    host_name        = each.value.host_name
    app_port         = each.value.app_port
    mongodb_database = each.value.mongodb_database
    start_command    = each.value.start_command
  }))

  dynamic "admin_ssh_key" {
    for_each = local.use_ssh_key_auth ? [var.admin_auth.ssh_public_key] : []

    content {
      username   = var.admin_username
      public_key = admin_ssh_key.value
    }
  }

  os_disk {
    name                 = "osdisk-${var.project_name}-${each.key}"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}
