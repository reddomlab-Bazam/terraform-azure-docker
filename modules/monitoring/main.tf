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
    })
  ]

  depends_on = [kubernetes_namespace.monitoring]
}

# Deploy Wazuh using official manifests
resource "null_resource" "deploy_wazuh" {
  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      set -e
      
      echo "Deploying Wazuh to AKS cluster..."
      
      # Check if wazuh namespace exists, create if not
      if ! kubectl get namespace wazuh > /dev/null 2>&1; then
        echo "Creating wazuh namespace..."
        kubectl create namespace wazuh
      fi
      
      # Create a temporary directory for Wazuh manifests
      TEMP_DIR=$(mktemp -d)
      cd $TEMP_DIR
      
      # Clone the official Wazuh Kubernetes repository
      echo "Cloning Wazuh Kubernetes repository..."
      git clone https://github.com/wazuh/wazuh-kubernetes.git -b v4.6.0 --depth=1
      cd wazuh-kubernetes
      
      # Apply base configurations first
      echo "Applying Wazuh base configurations..."
      kubectl apply -f wazuh/base/
      
      # Wait a bit for base resources to be created
      sleep 30
      
      # Apply indexer stack
      echo "Applying Wazuh indexer stack..."
      kubectl apply -f wazuh/indexer_stack/
      
      # Wait for indexer to be ready
      sleep 60
      
      # Apply manager and dashboard
      echo "Applying Wazuh manager and dashboard..."
      kubectl apply -f wazuh/manager/
      
      # Clean up
      rm -rf $TEMP_DIR
      
      echo "Wazuh deployment completed successfully"
    EOT
  }

  depends_on = [kubernetes_namespace.monitoring]
}

# Create service monitor for Prometheus to scrape Wazuh metrics
resource "kubernetes_manifest" "wazuh_service_monitor" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "wazuh-monitor"
      namespace = kubernetes_namespace.monitoring.metadata[0].name
      labels = {
        app = "wazuh"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          app = "wazuh-manager"
        }
      }
      namespaceSelector = {
        matchNames = ["wazuh"]
      }
      endpoints = [
        {
          port     = "api"
          interval = "30s"
          path     = "/api"
        }
      ]
    }
  }

  depends_on = [helm_release.prometheus, null_resource.deploy_wazuh]
}

# Create ConfigMap for lab documentation
resource "kubernetes_config_map" "lab_documentation" {
  metadata {
    name      = "lab-guide"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  data = {
    "instructions.md" = file("${path.module}/docs/lab_instructions.md")
    "architecture.md" = file("${path.module}/docs/architecture.md")
    "exercises.md"    = file("${path.module}/docs/exercises.md")
  }

  depends_on = [kubernetes_namespace.monitoring]
}

# Network policy to secure the monitoring namespace
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
            name = "monitoring"
          }
        }
      }
      
      from {
        namespace_selector {
          match_labels = {
            name = "wazuh"
          }
        }
      }
    }
    
    egress {
      to {
        namespace_selector {
          match_labels = {
            name = "wazuh"
          }
        }
      }
      
      # Allow egress to DNS
      to {}
      ports {
        protocol = "UDP"
        port     = "53"
      }
      
      # Allow egress to HTTPS
      to {}
      ports {
        protocol = "TCP"
        port     = "443"
      }
    }
  }

  depends_on = [kubernetes_namespace.monitoring]
}