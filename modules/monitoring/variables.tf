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

# Domain Configuration
variable "domain_name" {
  description = "Base domain name for services"
  type        = string
}

variable "grafana_subdomain" {
  description = "Subdomain for Grafana dashboard"
  type        = string
  default     = "grafana"
}

variable "wazuh_subdomain" {
  description = "Subdomain for Wazuh dashboard"
  type        = string
  default     = "wazuh"
}

# Optional: Cloudflare Zero Trust Integration
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

# Storage Configuration
variable "storage_class" {
  description = "Storage class for persistent volumes"
  type        = string
  default     = "managed-premium"
}

variable "grafana_storage_size" {
  description = "Size of storage for Grafana"
  type        = string
  default     = "10Gi"
}

# Resource Configuration
variable "grafana_resources" {
  description = "Resource limits and requests for Grafana"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "200m"
      memory = "500Mi"
    }
    limits = {
      cpu    = "1000m"
      memory = "2Gi"
    }
  }
}

# Monitoring Configuration
variable "enable_prometheus" {
  description = "Enable Prometheus monitoring"
  type        = bool
  default     = true
}

variable "enable_network_policies" {
  description = "Enable network policies for security"
  type        = bool
  default     = true
}

# Backup Configuration
variable "enable_backups" {
  description = "Enable automated backups"
  type        = bool
  default     = true
}

variable "backup_schedule" {
  description = "Cron schedule for backups"
  type        = string
  default     = "0 2 * * *"  # Daily at 2 AM
}