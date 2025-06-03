variable "environment" {
  description = "Environment name (prd, dev, stg)"
  type        = string
  default     = "prd"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "uksouth"
}

variable "location_prefix" {
  description = "Location prefix for naming"
  type        = string
  default     = "uks"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "Production"
    ManagedBy   = "Terraform"
    Security    = "High"
    Compliance  = "Required"
    Project     = "RedDome-Lab"
    Owner       = "Instructor"
    Lab         = "DevSecOps"
  }
}

# Grafana Configuration
variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
}

# Cloudflare Tunnel Configuration
variable "cloudflare_tunnel_token_grafana" {
  description = "Cloudflare tunnel token for Grafana"
  type        = string
  sensitive   = true
}

variable "cloudflare_tunnel_token_wazuh" {
  description = "Cloudflare tunnel token for Wazuh"
  type        = string
  sensitive   = true
}

# Network Security
variable "api_authorized_ranges" {
  description = "Authorized IP ranges for K8s API access"
  type        = list(string)
  sensitive   = true
}

variable "enable_monitoring" {
  description = "Enable Azure Monitor for containers"
  type        = bool
  default     = true
}

# Domain Configuration
variable "domain_name" {
  description = "Base domain name for services (e.g., reddomelab.com)"
  type        = string
}

variable "wazuh_subdomain" {
  description = "Subdomain for Wazuh dashboard"
  type        = string
  default     = "wazuh"
}

variable "grafana_subdomain" {
  description = "Subdomain for Grafana dashboard"
  type        = string
  default     = "grafana"
}

# Azure Monitor Integration
variable "log_analytics_workspace_id" {
  description = "ID of the existing Log Analytics workspace for Azure Sentinel"
  type        = string
}

# Optional: Cloudflare Zero Trust Integration
variable "cloudflare_api_token" {
  description = "Cloudflare API token for Zero Trust integration"
  type        = string
  sensitive   = true
  default     = ""
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID for Zero Trust integration"
  type        = string
  default     = ""
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID for DNS management"
  type        = string
  default     = ""
}

variable "enable_zero_trust_integration" {
  description = "Enable integration with Cloudflare Zero Trust"
  type        = bool
  default     = false
}

# AKS Configuration
variable "kubernetes_version" {
  description = "Version of Kubernetes for AKS cluster"
  type        = string
  default     = "1.28.5"  # Stable version
}

variable "node_count" {
  description = "Number of nodes in the default node pool"
  type        = number
  default     = 2  # Increased for better stability
}

variable "vm_size" {
  description = "Size of the VMs in the node pool"
  type        = string
  default     = "Standard_D2s_v3"
}

# Storage Configuration
variable "storage_account_name" {
  description = "Name of the storage account for backups"
  type        = string
  default     = ""
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 30
}