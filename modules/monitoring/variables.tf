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

variable "domain_name" {
  description = "Base domain name for services"
  type        = string
}

variable "grafana_subdomain" {
  description = "Subdomain for Grafana dashboard"
  type        = string
}

variable "wazuh_subdomain" {
  description = "Subdomain for Wazuh dashboard"
  type        = string
}

# Remove these variables if they aren't needed in the monitoring module
# variable "api_authorized_ranges" {
#   description = "Authorized IP ranges for K8s API access"
#   type        = list(string)
#   sensitive   = true
# }

# variable "environment" {
#   description = "Environment name (prd, dev, stg)"
#   type        = string
#   default     = "prd"
# }

# variable "location" {
#   description = "Azure region"
#   type        = string
#   default     = "uksouth"
# }

# variable "location_prefix" {
#   description = "Location prefix for naming"
#   type        = string
#   default     = "uks"
# }

# variable "enable_monitoring" {
#   description = "Enable Azure Monitor for containers"
#   type        = bool
#   default     = true
# }

# variable "tags" {
#   description = "Tags to apply to all resources"
#   type        = map(string)
#   default = {
#     Environment = "Production"
#     ManagedBy   = "Terraform"
#     Security    = "High"
#     Compliance  = "Required"
#     Project     = "RedDome-Lab"
#     Owner       = "Instructor"
#     Lab         = "DevSecOps"
#   }
# }