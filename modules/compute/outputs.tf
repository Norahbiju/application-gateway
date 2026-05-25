output "vmss_ids" {
  value = {
    for key, vmss in azurerm_linux_virtual_machine_scale_set.app : key => vmss.id
  }
}
