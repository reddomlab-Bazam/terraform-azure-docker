output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "aks_subnet_id" {
  value = azurerm_subnet.aks.id
}

output "vnet_id" {
  value = azurerm_virtual_network.vnet.id
}