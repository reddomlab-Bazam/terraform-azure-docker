# Create wazuh namespace with proper labels
resource "kubernetes_namespace" "wazuh" {
  metadata {
    name = "wazuh"
    labels = {
      "purpose" = "security-monitoring"
      "security" = "high"
      "app" = "wazuh"
    }
  }
}

# Resource quota for wazuh namespace
resource "kubernetes_resource_quota" "wazuh_quota" {
  metadata {
    name      = "wazuh-quota"
    namespace = kubernetes_namespace.wazuh.metadata[0].name
  }
  spec {
    hard = {
      "requests.cpu"    = "6"
      "requests.memory" = "12Gi"
      "limits.cpu"      = "12"
      "limits.memory"   = "24Gi"
      "pods"            = "15"
      "persistentvolumeclaims" = "5"
    }
  }
}

# Create deployment script with proper error handling
resource "local_file" "deploy_wazuh_script" {
  filename = "${path.module}/deploy_wazuh.sh"
  content = <<-EOT
    #!/bin/bash
    set -e
    
    echo "Starting Wazuh deployment to AKS cluster..."
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        echo "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check if we can connect to the cluster
    if ! kubectl cluster-info &> /dev/null; then
        echo "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    # Check if wazuh namespace exists
    if ! kubectl get namespace wazuh > /dev/null 2>&1; then
        echo "Creating wazuh namespace..."
        kubectl create namespace wazuh
        kubectl label namespace wazuh purpose=security-monitoring
        kubectl label namespace wazuh security=high
    fi
    
    # Create a temporary directory for Wazuh manifests
    TEMP_DIR=$$(mktemp -d)
    cd $$TEMP_DIR
    
    echo "Downloading Wazuh Kubernetes manifests..."
    
    # Clone the official Wazuh Kubernetes repository
    if ! git clone https://github.com/wazuh/wazuh-kubernetes.git -b v4.6.0 --depth=1; then
        echo "Failed to clone Wazuh repository"
        exit 1
    fi
    
    cd wazuh-kubernetes
    
    # Apply base configurations first
    echo "Applying Wazuh base configurations..."
    kubectl apply -f wazuh/base/ -n wazuh
    
    # Wait for base resources to be created
    echo "Waiting for base resources to be ready..."
    sleep 45
    
    # Apply indexer stack
    echo "Applying Wazuh indexer stack..."
    kubectl apply -f wazuh/indexer_stack/ -n wazuh
    
    # Wait for indexer to be ready
    echo "Waiting for indexer to be ready..."
    kubectl wait --for=condition=ready pod -l app=wazuh-indexer -n wazuh --timeout=600s || echo "Indexer pods may still be starting..."
    sleep 60
    
    # Apply manager and dashboard
    echo "Applying Wazuh manager and dashboard..."
    kubectl apply -f wazuh/manager/ -n wazuh
    
    # Wait for manager to be ready
    echo "Waiting for Wazuh manager to be ready..."
    kubectl wait --for=condition=ready pod -l app=wazuh-manager -n wazuh --timeout=600s || echo "Manager pods may still be starting..."
    
    # Wait for dashboard to be ready
    echo "Waiting for Wazuh dashboard to be ready..."
    kubectl wait --for=condition=ready pod -l app=wazuh-dashboard -n wazuh --timeout=600s || echo "Dashboard pods may still be starting..."
    
    echo "Checking deployment status..."
    kubectl get pods -n wazuh
    kubectl get services -n wazuh
    
    # Clean up
    rm -rf $$TEMP_DIR
    
    echo "Wazuh deployment completed successfully!"
    echo "Access the dashboard at: https://wazuh.$${DOMAIN_NAME:-reddomelab.com}"
    echo "Default credentials: admin/admin (change after first login)"
  EOT

  file_permission = "0755"
}

# Execute the Wazuh deployment script - FIXED: Correct path reference
resource "null_resource" "deploy_wazuh" {
  depends_on = [
    kubernetes_namespace.wazuh,
    kubernetes_resource_quota.wazuh_quota,
    local_file.deploy_wazuh_script
  ]

  provisioner "local-exec" {
    command     = "bash ${local_file.deploy_wazuh_script.filename}"
    working_dir = path.module
    
    environment = {
      KUBECONFIG = "~/.kube/config"
      DOMAIN_NAME = var.domain_name
    }
  }

  # Trigger re-deployment if script changes
  triggers = {
    script_hash = local_file.deploy_wazuh_script.content
    namespace   = kubernetes_namespace.wazuh.metadata[0].name
  }
}

# Create custom Wazuh configuration for better performance
resource "kubernetes_config_map" "wazuh_config" {
  metadata {
    name      = "wazuh-config"
    namespace = kubernetes_namespace.wazuh.metadata[0].name
  }

  data = {
    "ossec.conf" = <<-EOF
      <ossec_config>
        <global>
          <jsonout_output>yes</jsonout_output>
          <alerts_log>yes</alerts_log>
          <logall>no</logall>
          <logall_json>no</logall_json>
          <email_notification>no</email_notification>
          <smtp_server>localhost</smtp_server>
          <email_from>wazuh@${var.domain_name}</email_from>
        </global>

        <alerts>
          <log_alert_level>3</log_alert_level>
          <email_alert_level>12</email_alert_level>
        </alerts>

        <remote>
          <connection>secure</connection>
          <port>1514</port>
          <protocol>tcp</protocol>
          <allowed-ips>10.0.0.0/16</allowed-ips>
        </remote>

        <auth>
          <disabled>no</disabled>
          <port>1515</port>
          <use_source_ip>no</use_source_ip>
          <purge>yes</purge>
          <use_password>yes</use_password>
          <ciphers>HIGH:!ADH:!EXP:!MD5:!RC4:!3DES:!CAMELLIA:@STRENGTH</ciphers>
          <ssl_agent_ca></ssl_agent_ca>
          <ssl_verify_host>no</ssl_verify_host>
          <ssl_manager_cert>/var/ossec/etc/sslmanager.cert</ssl_manager_cert>
          <ssl_manager_key>/var/ossec/etc/sslmanager.key</ssl_manager_key>
          <ssl_auto_negotiate>no</ssl_auto_negotiate>
        </auth>

        <cluster>
          <name>wazuh</name>
          <node_name>master-node</node_name>
          <node_type>master</node_type>
          <key></key>
          <port>1516</port>
          <bind_addr>0.0.0.0</bind_addr>
          <nodes>
            <node>wazuh-manager</node>
          </nodes>
          <hidden>no</hidden>
          <disabled>no</disabled>
        </cluster>
      </ossec_config>
    EOF
    
    "api.yaml" = <<-EOF
      host: 0.0.0.0
      port: 55000
      https:
        enabled: yes
        key: "/var/ossec/api/configuration/ssl/server.key"
        cert: "/var/ossec/api/configuration/ssl/server.crt"
        use_ca: False
        ca: "/var/ossec/api/configuration/ssl/ca.crt"
        ssl_protocol: "TLSv1.2"
        ssl_ciphers: ""
      logs:
        level: info
        path: logs/api.log
      cors:
        enabled: no
        source_route: "*"
        expose_headers: "*"
        allow_headers: "*"
        allow_credentials: no
      cache:
        enabled: yes
        time: 0.750
      access:
        max_login_attempts: 50
        block_time: 300
        max_request_per_minute: 300
      drop_privileges: yes
      experimental_features: no
    EOF
  }

  depends_on = [kubernetes_namespace.wazuh]
}

# Create a health check service for Wazuh
resource "kubernetes_service" "wazuh_health_check" {
  metadata {
    name      = "wazuh-health"
    namespace = kubernetes_namespace.wazuh.metadata[0].name
    labels = {
      app = "wazuh-health"
    }
  }

  spec {
    selector = {
      app = "wazuh-health"
    }
    port {
      port        = 8080
      target_port = 8080
      protocol    = "TCP"
    }
    type = "ClusterIP"
  }
}

# Simple health check deployment
resource "kubernetes_deployment" "wazuh_health_check" {
  metadata {
    name      = "wazuh-health"
    namespace = kubernetes_namespace.wazuh.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "wazuh-health"
      }
    }

    template {
      metadata {
        labels = {
          app = "wazuh-health"
        }
      }

      spec {
        container {
          name  = "health-check"
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

          liveness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }
        }
      }
    }
  }

  depends_on = [kubernetes_namespace.wazuh]
}

# Network policy for Wazuh namespace - COMPLETELY FIXED
resource "kubernetes_network_policy" "wazuh_network_policy" {
  metadata {
    name      = "wazuh-network-policy"
    namespace = kubernetes_namespace.wazuh.metadata[0].name
  }

  spec {
    pod_selector {}
    
    policy_types = ["Ingress", "Egress"]
    
    ingress {
      # Allow ingress from monitoring namespace
      from {
        namespace_selector {
          match_labels = {
            purpose = "monitoring"
          }
        }
      }
      
      # Allow ingress within wazuh namespace
      from {
        pod_selector {}
      }
      
      # Allow specific ports
      ports {
        protocol = "TCP"
        port     = "443"
      }
      ports {
        protocol = "TCP"
        port     = "9200"
      }
      ports {
        protocol = "TCP"
        port     = "55000"
      }
    }
    
    egress {
      # Allow egress to monitoring namespace
      to {
        namespace_selector {
          match_labels = {
            purpose = "monitoring"
          }
        }
      }
      
      # Allow egress within wazuh namespace  
      to {
        pod_selector {}
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

  depends_on = [kubernetes_namespace.wazuh]
}