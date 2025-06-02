terraform {
  backend "remote" {
    organization = "gvolt"
    workspaces {
      name = "terraform-azure-docker"
    }
  }
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.9.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20.0"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = false
    }
  }
}

provider "helm" {
  kubernetes {
    host                   = module.aks.host
    client_certificate     = base64decode(module.aks.client_certificate)
    client_key             = base64decode(module.aks.client_key)
    cluster_ca_certificate = base64decode(module.aks.cluster_ca_certificate)
  }
}

provider "kubernetes" {
  host                   = module.aks.host
  client_certificate     = base64decode(module.aks.client_certificate)
  client_key             = base64decode(module.aks.client_key)
  cluster_ca_certificate = base64decode(module.aks.cluster_ca_certificate)
}

module "networking" {
  source          = "./modules/networking"
  environment     = var.environment
  location        = var.location
  location_prefix = var.location_prefix
  tags            = var.tags
}

module "aks" {
  source                  = "./modules/aks"
  environment             = var.environment
  location                = var.location
  location_prefix         = var.location_prefix
  resource_group_name     = module.networking.resource_group_name
  subnet_id               = module.networking.aks_subnet_id
  tags                    = var.tags
  api_authorized_ranges   = var.api_authorized_ranges
  enable_monitoring       = var.enable_monitoring
  log_analytics_workspace_id = var.log_analytics_workspace_id
}

# First ensure the providers are properly initialized using the AKS cluster config
module "wazuh" {
  source     = "./modules/wazuh"
  depends_on = [module.aks]
}

# Use a local-exec provisioner to ensure AKS is ready before deploying monitoring
resource "null_resource" "wait_for_aks" {
  depends_on = [module.aks]

  provisioner "local-exec" {
    command = "sleep 60"  # Give AKS time to fully initialize
  }
}

# Then deploy the monitoring module
module "monitoring" {
  source                          = "./modules/monitoring"
  grafana_admin_password          = var.grafana_admin_password
  cloudflare_tunnel_token_grafana = var.cloudflare_tunnel_token_grafana
  cloudflare_tunnel_token_wazuh   = var.cloudflare_tunnel_token_wazuh
  domain_name                     = var.domain_name
  grafana_subdomain               = var.grafana_subdomain
  wazuh_subdomain                 = var.wazuh_subdomain
  
  depends_on = [null_resource.wait_for_aks]
}