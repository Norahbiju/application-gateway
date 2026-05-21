output "backend_targets" {
  value = {
    for key, vm in azurerm_linux_virtual_machine.app : key => {
      private_ip   = vm.private_ip_address
      host_name    = var.apps[key].host_name
      display_name = var.apps[key].display_name
    }
  }
}
