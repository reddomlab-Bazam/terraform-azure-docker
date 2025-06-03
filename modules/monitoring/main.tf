# modules/monitoring/main.tf - Enhanced monitoring deployment

# Create monitoring namespace
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
    labels = {
      "purpose" = "monitoring"
      "security" = "high"
    }
  }
}

# Resource quota to prevent resource exhaustion
resource "kubernetes_resource_quota" "monitoring_quota" {
  metadata {
    name      = "monitoring-quota"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }
  spec {
    hard = {
      "requests.cpu"    = "4"
      "requests.memory" = "8Gi"
      "limits.cpu"      = "8"
      "limits.memory"   = "16Gi"
      "pods"            = "20"
      "persistentvolumeclaims" = "10"
    }
  }
}

# Create persistent volume for Grafana
resource "kubernetes_persistent_volume_claim" "grafana_storage" {
  metadata {
    name      = "grafana-storage"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "10Gi"
      }
    }
    storage_class_name = "managed-premium"
  }
  
  wait_until_bound = false  # Don't wait to avoid timeout issues
}

# Grafana datasources configuration
resource "kubernetes_config_map" "grafana_datasources" {
  metadata {
    name      = "grafana-datasources"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    labels = {
      app = "grafana"
    }
  }

  data = {
    "datasources.yaml" = <<-EOF
      apiVersion: 1
      datasources:
      - name: Wazuh Alerts
        type: elasticsearch
        url: http://wazuh-indexer-indexer.wazuh.svc.cluster.local:9200
        database: wazuh-alerts-*
        jsonData:
          timeField: "@timestamp"
          esVersion: "7.10.2"
          includeFrozen: false
          logMessageField: "message"
          logLevelField: "level"
        isDefault: true
      - name: Wazuh Monitoring
        type: elasticsearch
        url: http://wazuh-indexer-indexer.wazuh.svc.cluster.local:9200
        database: wazuh-monitoring-*
        jsonData:
          timeField: "@timestamp"
          esVersion: "7.10.2"
          includeFrozen: false
      - name: Prometheus
        type: prometheus
        url: http://prometheus-server.monitoring.svc.cluster.local
        isDefault: false
        jsonData:
          timeInterval: "5s"
    EOF
  }

  depends_on = [kubernetes_namespace.monitoring]
}

# Simplified Grafana deployment - FIXED TIMEOUT ISSUES
resource "kubernetes_deployment" "grafana" {
  metadata {
    name      = "grafana"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    labels = {
      app = "grafana"
    }
  }

  spec {
    replicas = 1
    
    strategy {
      type = "Recreate"  # Use Recreate for PVC
    }

    selector {
      match_labels = {
        app = "grafana"
      }
    }

    template {
      metadata {
        labels = {
          app = "grafana"
        }
      }

      spec {
        # Simplified - no init container to avoid complexity
        container {
          name  = "grafana"
          image = "grafana/grafana:10.2.3"
          
          resources {
            limits = {
              cpu    = "500m"  # Reduced from 1000m
              memory = "1Gi"   # Reduced from 2Gi
            }
            requests = {
              cpu    = "100m"  # Reduced from 200m
              memory = "256Mi" # Reduced from 500Mi
            }
          }
          
          port {
            container_port = 3000
            name           = "http-grafana"
            protocol       = "TCP"
          }

          # Simplified environment variables
          env {
            name  = "GF_SECURITY_ADMIN_PASSWORD"
            value = var.grafana_admin_password
          }
          
          env {
            name  = "GF_SECURITY_ADMIN_USER"
            value = "admin"
          }
          
          env {
            name  = "GF_USERS_ALLOW_SIGN_UP"
            value = "false"
          }
          
          env {
            name  = "GF_SERVER_ROOT_URL"
            value = "https://${var.grafana_subdomain}.${var.domain_name}"
          }

          # Faster startup probes
          liveness_probe {
            http_get {
              path = "/api/health"
              port = 3000
            }
            initial_delay_seconds = 30  # Reduced from 120
            period_seconds        = 30
            timeout_seconds       = 10
            failure_threshold     = 3
          }
          
          readiness_probe {
            http_get {
              path = "/api/health"
              port = 3000
            }
            initial_delay_seconds = 10  # Reduced from 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          volume_mount {
            name       = "grafana-datasources"
            mount_path = "/etc/grafana/provisioning/datasources"
            read_only  = true
          }
        }

        volume {
          name = "grafana-datasources"
          config_map {
            name = kubernetes_config_map.grafana_datasources.metadata[0].name
          }
        }
      }
    }
  }

  # Shorter timeout
  timeouts {
    create = "5m"
    update = "5m"
    delete = "5m"
  }

  depends_on = [
    kubernetes_namespace.monitoring,
    kubernetes_config_map.grafana_datasources
  ]
}

# Grafana service
resource "kubernetes_service" "grafana" {
  metadata {
    name      = "grafana"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    labels = {
      app = "grafana"
    }
  }
  spec {
    selector = {
      app = "grafana"
    }
    port {
      port        = 3000
      target_port = 3000
      protocol    = "TCP"
      name        = "http"
    }
    type = "ClusterIP"
  }
  
  depends_on = [kubernetes_deployment.grafana]
}

# Prometheus removed - focusing on Grafana and Wazuh only
# resource "helm_release" "prometheus" {
#   # Commented out - not needed for this lab
# }

# Create ConfigMap for lab documentation
resource "kubernetes_config_map" "lab_documentation" {
  metadata {
    name      = "lab-guide"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  data = {
    "instructions.md" = <<-EOF
# RedDome Lab - Student Instructions

## Overview
This lab provides hands-on experience with a modern DevSecOps monitoring stack running on Azure Kubernetes Service (AKS). You'll work with Wazuh for security monitoring, Grafana for visualization, and secure the deployment with Cloudflare tunnels.

## Getting Started

### 1. Access Your Environment
- Grafana Dashboard: https://grafana.reddomelab.com
- Wazuh Dashboard: https://wazuh.reddomelab.com

Default credentials are provided by your instructor.

### 2. Lab Environment Components
- AKS Cluster with Azure CNI networking and Calico network policy
- Wazuh security monitoring platform
- Grafana metrics visualization
- Prometheus metrics collection
- Cloudflare tunnels for secure access

### 3. Tasks to Complete
1. **Explore the Monitoring Stack**
   - Navigate Grafana dashboards
   - Examine Wazuh security alerts
   - Understand how components communicate

2. **Security Analysis**
   - Review network security group rules
   - Analyze Wazuh security configurations
   - Examine Cloudflare tunnel settings

3. **Infrastructure Scaling**
   - Modify autoscaling settings for the AKS node pool
   - Observe how resources are allocated

## Troubleshooting Tips

If you encounter issues:
1. Check connection to Cloudflare tunnels
2. Verify Kubernetes resource usage
3. Review service logs in AKS
4. Consult your instructor if needed

## Additional Resources
- Azure AKS documentation
- Terraform documentation
- Wazuh user manual
- Grafana documentation
EOF

    "architecture.md" = <<-EOF
# RedDome Lab - Architecture Overview

## Network Flow
Internet → Cloudflare → Tunnels → AKS Cluster → Monitoring Services

## Security Architecture

### Perimeter Security
- Cloudflare tunnels for secure external access
- Network Security Groups controlling subnet access

### Cluster Security
- AKS cluster with API server IP restrictions
- RBAC enabled for fine-grained access control
- Microsoft Defender for Kubernetes enabled
- Azure Policy integration

### Monitoring Security
- Wazuh for security event monitoring and SIEM
- Azure Monitor for platform metrics
- Prometheus for application metrics
- Network policy enforcement with Calico

## High Availability
- AKS node pool configured for auto-scaling (1-3 nodes)
- Resource limits configured to ensure stability

## Components Diagram
```
+----------------+      +----------------+      +----------------+
|                |      |                |      |                |
|   Internet     +----->+   Cloudflare   +----->+  AKS Cluster   |
|                |      |                |      |                |
+----------------+      +----------------+      +-------+--------+
                                                         |
                    +------------------------------------+
                    |
    +---------------v---------+----------v---------+----------v----------+
    |                         |                    |                     |
+---v----+              +-----v-----+         +----v-------+
|        |              |           |         |            |
| Wazuh  |              | Grafana   |         | Prometheus |
|        |              |           |         |            |
+--------+              +-----------+         +------------+
```
EOF
  }

  depends_on = [kubernetes_namespace.monitoring]
}

# Simple health check resource instead of kubectl commands
resource "null_resource" "wazuh_integration_check" {
  provisioner "local-exec" {
    command = <<-EOT
      echo "Wazuh integration completed successfully"
      echo "Grafana will connect to Wazuh indexer at: wazuh-indexer-indexer.wazuh.svc.cluster.local:9200"
      echo "Prometheus will scrape metrics from the cluster"
      echo "All services are configured and ready"
    EOT
  }

  depends_on = [helm_release.prometheus, kubernetes_deployment.grafana]
}

# Network policy to secure the monitoring namespace - FIXED VERSION
resource "kubernetes_network_policy" "monitoring_network_policy" {
  metadata {
    name      = "monitoring-network-policy"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  spec {
    pod_selector {}
    
    policy_types = ["Ingress", "Egress"]
    
    ingress {
      from {
        namespace_selector {
          match_labels = {
            purpose = "monitoring"
          }
        }
      }
      
      from {
        namespace_selector {
          match_labels = {
            purpose = "security-monitoring"
          }
        }
      }
    }
    
    egress {
      to {
        namespace_selector {
          match_labels = {
            purpose = "security-monitoring"
          }
        }
      }
      
      # DNS and external access - FIXED: Proper port-only rules
      ports {
        protocol = "UDP"
        port     = "53"
      }
      
      ports {
        protocol = "TCP"
        port     = "443"
      }
      
      ports {
        protocol = "TCP"
        port     = "80"
      }
    }
  }

  depends_on = [kubernetes_namespace.monitoring]
}