variable "environment" {
  description = "Environment name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "location_prefix" {
  description = "Location prefix for naming"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "subnet_id" {
  description = "ID of the subnet where the AKS cluster will be deployed"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
}

variable "api_authorized_ranges" {
  description = "Authorized IP ranges for K8s API access"
  type        = list(string)
}

variable "enable_monitoring" {
  description = "Enable Azure Monitor for containers"
  type        = bool
}

variable "kubernetes_version" {
  description = "Version of Kubernetes"
  type        = string
  default     = "1.32.3"  # Try this generally available version
}

variable "node_count" {
  description = "Number of nodes in the default node pool"
  type        = number
  default     = 1
}

variable "vm_size" {
  description = "Size of the VMs in the node pool"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "log_analytics_workspace_id" {
  description = "ID of the existing Log Analytics workspace for Azure Sentinel"
  type        = string
}