# Minimal terraform.tfvars - Most variables are in Terraform Cloud workspace

# Optional: Override defaults if needed
# environment     = "prd"
# location        = "uksouth"
# location_prefix = "uks"

# Optional: Resource Tags (can be customized per deployment)
tags = {
  Environment = "Production"
  ManagedBy   = "Terraform"
  Security    = "High"
  Compliance  = "Required"
  Project     = "RedDome-Lab"
  Owner       = "Instructor"
  Lab         = "DevSecOps"
  CostCenter  = "IT-Security"
  Department  = "Education"
}