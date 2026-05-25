output "application_gateway_public_ip" {
  description = "Public IP address of the WAF_v2 Application Gateway."
  value       = module.application_gateway.public_ip_address
}

output "routes" {
  description = "Application hostnames exposed by the Application Gateway."
  value = {
    organic = "http://organic.nexaflow.site"
    fitness = "http://fitness.nexaflow.site"
  }
}

output "dns_a_records" {
  description = "DNS A records to create at your DNS provider after apply."
  value = {
    "organic.nexaflow.site" = module.application_gateway.public_ip_address
    "fitness.nexaflow.site" = module.application_gateway.public_ip_address
  }
}

output "selected_vm_size" {
  description = "VM size used for backend VMSS instances."
  value       = var.vm_size
}

output "firewall_public_ip" {
  description = "Public IP address of the Azure Firewall."
  value       = module.network.firewall_public_ip_address
}

output "bastion_public_ip" {
  description = "Public IP address of the Azure Bastion host."
  value       = module.network.bastion_public_ip_address
}

output "cosmosdb_account_name" {
  description = "Cosmos DB Mongo API account used by both applications."
  value       = module.cosmosdb.account_name
}

output "vmss_ids" {
  description = "VM scale set resource IDs by app."
  value       = module.compute.vmss_ids
}
