locals {
  cluster_name = "aks-${var.location_prefix}-${var.environment}"
  dns_prefix   = "aks-${var.location_prefix}-${var.environment}"
  
  default_node_pool_settings = {
    name                = "system"
    vm_size            = var.vm_size
    enable_auto_scaling = true
    min_count          = 1
    max_count          = 3
    os_disk_size_gb    = 50
  }
}
