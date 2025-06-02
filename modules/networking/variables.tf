variable "environment" {
  description = "Environment name (prd, dev, stg)"
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

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
}
