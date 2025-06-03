# Enhanced Cloudflare tunnel configuration for Grafana
resource "helm_release" "cloudflared_grafana" {
  name       = "cloudflared-grafana"
  repository = "https://charts.pascaliske.dev"
  chart      = "cloudflared"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = "1.3.0"
  timeout    = 600
  
  # Wait for Grafana to be ready before deploying tunnel
  depends_on = [kubernetes_deployment.grafana, kubernetes_service.grafana]

  values = [
    templatefile("${path.module}/values/cloudflare-grafana-values.yaml", {
      CLOUDFLARE_TUNNEL_TOKEN_GRAFANA = var.cloudflare_tunnel_token_grafana
      GRAFANA_SUBDOMAIN               = var.grafana_subdomain
      DOMAIN_NAME                     = var.domain_name
    })
  ]

  # Health check to ensure tunnel is properly configured
  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for Grafana tunnel to be ready..."
      sleep 60
      kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=cloudflared -n ${kubernetes_namespace.monitoring.metadata[0].name} --timeout=300s
    EOT
  }
}

# Enhanced Cloudflare tunnel configuration for Wazuh
resource "helm_release" "cloudflared_wazuh" {
  name       = "cloudflared-wazuh"
  repository = "https://charts.pascaliske.dev"
  chart      = "cloudflared"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = "1.3.0"
  timeout    = 600
  
  # Wait for Wazuh to be deployed before creating tunnel
  depends_on = [null_resource.deploy_wazuh]

  values = [
    templatefile("${path.module}/values/cloudflare-wazuh-values.yaml", {
      CLOUDFLARE_TUNNEL_TOKEN_WAZUH = var.cloudflare_tunnel_token_wazuh
      WAZUH_SUBDOMAIN               = var.wazuh_subdomain
      DOMAIN_NAME                   = var.domain_name
    })
  ]

  # Health check to ensure tunnel is properly configured
  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for Wazuh tunnel to be ready..."
      sleep 60
      kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=cloudflared -n ${kubernetes_namespace.monitoring.metadata[0].name} --timeout=300s
    EOT
  }
}

# Optional: Create DNS records if Zero Trust integration is enabled
resource "null_resource" "create_dns_records" {
  count = var.enable_zero_trust_integration ? 1 : 0
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "DNS records for tunnels should be configured in Cloudflare Dashboard"
      echo "Grafana: ${var.grafana_subdomain}.${var.domain_name}"
      echo "Wazuh: ${var.wazuh_subdomain}.${var.domain_name}"
      echo "Tunnel configuration completed successfully"
    EOT
  }
  
  depends_on = [helm_release.cloudflared_grafana, helm_release.cloudflared_wazuh]
}

# Create a service to test tunnel connectivity
resource "kubernetes_service" "tunnel_health_check" {
  metadata {
    name      = "tunnel-health-check"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    labels = {
      app = "tunnel-health-check"
    }
  }
  
  spec {
    selector = {
      app = "nginx"  # Simple nginx pod for testing
    }
    port {
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }
    type = "ClusterIP"
  }
}

# Simple nginx deployment for tunnel testing
resource "kubernetes_deployment" "tunnel_health_check" {
  metadata {
    name      = "tunnel-health-check"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }
  
  spec {
    replicas = 1
    
    selector {
      match_labels = {
        app = "nginx"
      }
    }
    
    template {
      metadata {
        labels = {
          app = "nginx"
        }
      }
      
      spec {
        container {
          name  = "nginx"
          image = "nginx:alpine"
          
          resources {
            requests = {
              cpu    = "10m"
              memory = "16Mi"
            }
            limits = {
              cpu    = "50m"
              memory = "64Mi"
            }
          }
          
          port {
            container_port = 80
            protocol       = "TCP"
          }
        }
      }
    }
  }
}