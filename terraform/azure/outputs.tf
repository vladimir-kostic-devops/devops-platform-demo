output "public_ip" {
  description = "Public IP address of the VM"
  value       = azurerm_public_ip.main.ip_address
}

output "ssh_command" {
  description = "SSH command to connect to the VM"
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.main.ip_address}"
}

output "resource_group" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}
