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

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
}

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

variable "domain_name" {
  description = "Base domain name for services (e.g., your-domain.com)"
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

variable "log_analytics_workspace_id" {
  description = "ID of the existing Log Analytics workspace for Azure Sentinel"
  type        = string
}