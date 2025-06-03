# Domain configuration for Wazuh
variable "domain_name" {
  description = "Base domain name for services"
  type        = string
  default     = "example.com"
}

# Wazuh configuration
variable "wazuh_version" {
  description = "Version of Wazuh to deploy"
  type        = string
  default     = "4.6.0"
}

variable "indexer_replicas" {
  description = "Number of Wazuh indexer replicas"
  type        = number
  default     = 1
}

variable "manager_replicas" {
  description = "Number of Wazuh manager replicas"
  type        = number
  default     = 1
}

variable "dashboard_replicas" {
  description = "Number of Wazuh dashboard replicas"
  type        = number
  default     = 1
}

# Storage configuration
variable "storage_class" {
  description = "Storage class for persistent volumes"
  type        = string
  default     = "managed-premium"
}

variable "indexer_storage_size" {
  description = "Storage size for Wazuh indexer"
  type        = string
  default     = "50Gi"
}

# Resource configuration
variable "indexer_resources" {
  description = "Resource limits for Wazuh indexer"
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
      cpu    = "500m"
      memory = "2Gi"
    }
    limits = {
      cpu    = "2000m"
      memory = "4Gi"
    }
  }
}

variable "manager_resources" {
  description = "Resource limits for Wazuh manager"
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
      cpu    = "500m"
      memory = "1Gi"
    }
    limits = {
      cpu    = "1000m"
      memory = "2Gi"
    }
  }
}

variable "dashboard_resources" {
  description = "Resource limits for Wazuh dashboard"
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
      memory = "512Mi"
    }
    limits = {
      cpu    = "500m"
      memory = "1Gi"
    }
  }
}

# Security configuration
variable "enable_ssl" {
  description = "Enable SSL for Wazuh components"
  type        = bool
  default     = true
}

variable "admin_password" {
  description = "Admin password for Wazuh dashboard"
  type        = string
  sensitive   = true
  default     = "admin"
}

# Network configuration
variable "cluster_key" {
  description = "Cluster key for Wazuh cluster communication"
  type        = string
  sensitive   = true
  default     = ""
}