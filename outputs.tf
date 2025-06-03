# AKS Cluster Information
output "aks_cluster_name" {
  description = "Name of the AKS cluster"
  value       = module.aks.cluster_name
}

output "aks_cluster_fqdn" {
  description = "FQDN of the AKS cluster"
  value       = module.aks.cluster_fqdn
}

output "aks_node_resource_group" {
  description = "Resource group containing the AKS cluster nodes"
  value       = module.aks.node_resource_group
}

# Network Information
output "resource_group_name" {
  description = "Name of the resource group"
  value       = module.networking.resource_group_name
}

output "vnet_id" {
  description = "ID of the virtual network"
  value       = module.networking.vnet_id
}

output "aks_subnet_id" {
  description = "ID of the AKS subnet"
  value       = module.networking.aks_subnet_id
}

# Monitoring Services URLs
output "grafana_url" {
  description = "URL to access Grafana dashboard"
  value       = "https://${var.grafana_subdomain}.${var.domain_name}"
}

output "wazuh_url" {
  description = "URL to access Wazuh dashboard"
  value       = "https://${var.wazuh_subdomain}.${var.domain_name}"
}

output "prometheus_url" {
  description = "Internal URL to access Prometheus (port-forward required)"
  value       = "http://prometheus-server.monitoring.svc.cluster.local"
}

# Monitoring Configuration
output "monitoring_namespace" {
  description = "Kubernetes namespace for monitoring components"
  value       = "monitoring"
}

output "wazuh_namespace" {
  description = "Kubernetes namespace for Wazuh components"
  value       = "wazuh"
}

# Connection Commands
output "kubectl_config_command" {
  description = "Command to configure kubectl for this cluster"
  value       = "az aks get-credentials --resource-group ${module.networking.resource_group_name} --name ${module.aks.cluster_name}"
}

output "grafana_port_forward_command" {
  description = "Command to access Grafana locally via port-forward"
  value       = "kubectl port-forward -n monitoring svc/grafana 3000:3000"
}

output "wazuh_port_forward_command" {
  description = "Command to access Wazuh locally via port-forward"
  value       = "kubectl port-forward -n wazuh svc/wazuh-dashboard 5601:443"
}

output "prometheus_port_forward_command" {
  description = "Command to access Prometheus locally via port-forward"
  value       = "kubectl port-forward -n monitoring svc/prometheus-server 9090:80"
}

# Security Information
output "grafana_admin_user" {
  description = "Grafana admin username"
  value       = "admin"
}

output "wazuh_admin_user" {
  description = "Wazuh admin username"
  value       = "admin"
}

output "wazuh_default_password" {
  description = "Wazuh default password (change after first login)"
  value       = "admin"
  sensitive   = false
}

# Lab Instructions
output "lab_access_instructions" {
  description = "Instructions for accessing the lab environment"
  value = <<-EOT
    
    🚀 RedDome Lab - Access Instructions
    ====================================
    
    1. Configure kubectl:
       ${module.aks.kubectl_config_command}
    
    2. Access Services:
       - Grafana: https://${var.grafana_subdomain}.${var.domain_name}
       - Wazuh: https://${var.wazuh_subdomain}.${var.domain_name}
    
    3. Default Credentials:
       - Grafana: admin / [your-configured-password]
       - Wazuh: admin / admin (CHANGE AFTER FIRST LOGIN)
    
    4. Local Access (if needed):
       - Grafana: kubectl port-forward -n monitoring svc/grafana 3000:3000
       - Wazuh: kubectl port-forward -n wazuh svc/wazuh-dashboard 5601:443
       - Prometheus: kubectl port-forward -n monitoring svc/prometheus-server 9090:80
    
    5. Useful Commands:
       - Check pods: kubectl get pods -A
       - Check services: kubectl get svc -A
       - View logs: kubectl logs -f <pod-name> -n <namespace>
    
    📚 Documentation available in: kubectl get configmap lab-guide -n monitoring -o yaml
    
  EOT
}

# Infrastructure Summary
output "infrastructure_summary" {
  description = "Summary of deployed infrastructure"
  value = {
    cluster_name          = module.aks.cluster_name
    resource_group        = module.networking.resource_group_name
    location              = var.location
    environment           = var.environment
    grafana_url          = "https://${var.grafana_subdomain}.${var.domain_name}"
    wazuh_url            = "https://${var.wazuh_subdomain}.${var.domain_name}"
    monitoring_namespace = "monitoring"
    wazuh_namespace      = "wazuh"
    domain_name          = var.domain_name
  }
}

# Terraform Cloud Integration
output "terraform_workspace_info" {
  description = "Information about the Terraform workspace"
  value = {
    organization = "gvolt"
    workspace    = "terraform-azure-docker"
    environment  = var.environment
  }
}