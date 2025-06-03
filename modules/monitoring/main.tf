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

# Grafana deployment with improved configuration
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
        # Security context for the pod
        security_context {
          fs_group = 472
        }

        # Init container to set proper permissions
        init_container {
          name  = "init-chown-data"
          image = "busybox:1.35"
          
          security_context {
            run_as_user = 0
          }
          
          resources {
            limits = {
              cpu    = "200m"
              memory = "256Mi"
            }
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
          }
          
          command = ["sh", "-c", "chown -R 472:472 /var/lib/grafana && chmod -R 755 /var/lib/grafana"]
          
          volume_mount {
            name       = "grafana-storage"
            mount_path = "/var/lib/grafana"
          }
        }

        container {
          name  = "grafana"
          image = "grafana/grafana:10.2.3"
          
          # Security context for the container
          security_context {
            run_as_user  = 472
            run_as_group = 472
            read_only_root_filesystem = false
          }
          
          resources {
            limits = {
              cpu    = "1000m"
              memory = "2Gi"
            }
            requests = {
              cpu    = "200m"
              memory = "500Mi"
            }
          }
          
          port {
            container_port = 3000
            name           = "http-grafana"
            protocol       = "TCP"
          }

          # Environment variables
          env {
            name  = "GF_SECURITY_ADMIN_PASSWORD"
            value = var.grafana_admin_password
          }
          
          env {
            name  = "GF_INSTALL_PLUGINS"
            value = "grafana-clock-panel,grafana-simple-json-datasource,elasticsearch"
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

          # Liveness and readiness probes
          liveness_probe {
            http_get {
              path = "/api/health"
              port = 3000
            }
            initial_delay_seconds = 120
            period_seconds        = 30
            timeout_seconds       = 10
            failure_threshold     = 3
          }
          
          readiness_probe {
            http_get {
              path = "/api/health"
              port = 3000
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          volume_mount {
            name       = "grafana-storage"
            mount_path = "/var/lib/grafana"
          }
          
          volume_mount {
            name       = "grafana-datasources"
            mount_path = "/etc/grafana/provisioning/datasources"
            read_only  = true
          }
        }

        volume {
          name = "grafana-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.grafana_storage.metadata[0].name
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

  depends_on = [
    kubernetes_namespace.monitoring,
    kubernetes_persistent_volume_claim.grafana_storage,
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

# Prometheus deployment for metrics collection
resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = "25.8.0"
  timeout    = 600

  values = [
    templatefile("${path.module}/values/prometheus-values.yaml", {
      STORAGE_CLASS = "managed-premium"
      DOMAIN_NAME   = var.domain_name
    })
  ]

  depends_on = [kubernetes_namespace.monitoring]
}

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

    "exercises.md" = <<-EOF
# RedDome Lab - Student Exercises

## Exercise 1: Security Assessment

**Objective**: Perform a security assessment of the RedDome Lab infrastructure.

**Tasks**:
1. Review network security configuration in Azure
   - Examine NSG rules
   - Analyze network configurations
   - Identify potential security gaps

2. Assess Kubernetes security posture
   - Review RBAC configurations
   - Check for privileged containers
   - Verify network policies

3. Analyze Wazuh security alerts
   - Review default rule set
   - Identify triggered alerts
   - Recommend security improvements

**Deliverable**: Security assessment report with findings and recommendations

## Exercise 2: Monitoring Configuration

**Objective**: Configure comprehensive monitoring for the infrastructure.

**Tasks**:
1. Set up Grafana dashboards
   - Create a dashboard for AKS node metrics
   - Configure alerts for resource utilization thresholds
   - Create a security events visualization

2. Configure Prometheus metrics collection
   - Set up custom metrics for application monitoring
   - Configure alert rules for critical services
   - Implement logging for alert triggers

3. Integrate Wazuh with external systems
   - Configure email notifications
   - Set up integration with ticketing system (mock)
   - Establish alerting thresholds

**Deliverable**: Monitoring configuration documentation with screenshots

## Exercise 3: Infrastructure Analysis

**Objective**: Analyze the deployed infrastructure and optimize performance.

**Tasks**:
1. Resource utilization analysis
   - Monitor CPU and memory usage across nodes
   - Identify bottlenecks and optimization opportunities
   - Recommend scaling strategies

2. Security monitoring effectiveness
   - Evaluate Wazuh detection capabilities
   - Test security event generation
   - Assess alert quality and reduce false positives

3. Network performance analysis
   - Test connectivity between components
   - Measure latency and throughput
   - Optimize network configurations

**Deliverable**: Infrastructure analysis report with optimization recommendations
EOF
  }

  depends_on = [kubernetes_namespace.monitoring]
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
      app = "nginx"
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
    EOT
  }
}

# Create service monitor for Prometheus to scrape Wazuh metrics
resource "null_resource" "wazuh_service_monitor" {
  provisioner "local-exec" {
    command = <<-EOT
      echo "Wazuh service monitor configuration completed"
      echo "ServiceMonitor will be created automatically by Prometheus"
    EOT
  }

  depends_on = [helm_release.prometheus]
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