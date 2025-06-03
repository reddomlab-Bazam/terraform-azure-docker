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

# Deploy Wazuh using Kubernetes resources directly instead of external script
resource "kubernetes_service" "wazuh_indexer" {
  metadata {
    name      = "wazuh-indexer-indexer"
    namespace = kubernetes_namespace.wazuh.metadata[0].name
  }
  spec {
    port {
      port        = 9200
      name        = "indexer-rest"
      protocol    = "TCP"
    }
    port {
      port        = 9300
      name        = "indexer-nodes"
      protocol    = "TCP"
    }
    cluster_ip = "None"
    selector = {
      app = "wazuh-indexer"
    }
  }
}

resource "kubernetes_stateful_set" "wazuh_indexer" {
  metadata {
    name      = "wazuh-indexer-indexer"
    namespace = kubernetes_namespace.wazuh.metadata[0].name
  }

  spec {
    service_name = "wazuh-indexer-indexer"
    replicas     = 1

    selector {
      match_labels = {
        app = "wazuh-indexer"
      }
    }

    template {
      metadata {
        labels = {
          app = "wazuh-indexer"
        }
      }

      spec {
        security_context {
          fs_group = 1000
        }

        container {
          name  = "wazuh-indexer"
          image = "wazuh/wazuh-indexer:4.6.0"

          port {
            container_port = 9200
            name           = "indexer-rest"
          }
          port {
            container_port = 9300
            name           = "indexer-nodes"
          }

          env {
            name  = "OPENSEARCH_JAVA_OPTS"
            value = "-Xms1g -Xmx1g"
          }
          env {
            name  = "bootstrap.memory_lock"
            value = "true"
          }

          security_context {
            capabilities {
              add = ["IPC_LOCK", "SYS_RESOURCE"]
            }
          }

          resources {
            requests = {
              memory = "2Gi"
              cpu    = "500m"
            }
            limits = {
              memory = "4Gi"
              cpu    = "1000m"
            }
          }

          volume_mount {
            name       = "wazuh-indexer"
            mount_path = "/var/lib/wazuh-indexer"
          }
        }
      }
    }

    volume_claim_template {
      metadata {
        name = "wazuh-indexer"
      }
      spec {
        access_modes = ["ReadWriteOnce"]
        storage_class_name = "managed-premium"
        resources {
          requests = {
            storage = "50Gi"
          }
        }
      }
    }
  }

  depends_on = [kubernetes_namespace.wazuh]
}

# Wazuh Manager Service
resource "kubernetes_service" "wazuh_manager" {
  metadata {
    name      = "wazuh-manager"
    namespace = kubernetes_namespace.wazuh.metadata[0].name
  }
  spec {
    port {
      port        = 1514
      name        = "agents"
      protocol    = "TCP"
    }
    port {
      port        = 1515
      name        = "authd"
      protocol    = "TCP"
    }
    port {
      port        = 55000
      name        = "api"
      protocol    = "TCP"
    }
    selector = {
      app = "wazuh-manager"
    }
  }
}

# Wazuh Manager StatefulSet
resource "kubernetes_stateful_set" "wazuh_manager" {
  metadata {
    name      = "wazuh-manager"
    namespace = kubernetes_namespace.wazuh.metadata[0].name
  }

  spec {
    service_name = "wazuh-manager"
    replicas     = 1

    selector {
      match_labels = {
        app = "wazuh-manager"
      }
    }

    template {
      metadata {
        labels = {
          app = "wazuh-manager"
        }
      }

      spec {
        container {
          name  = "wazuh-manager"
          image = "wazuh/wazuh-manager:4.6.0"

          port {
            container_port = 1514
          }
          port {
            container_port = 1515
          }
          port {
            container_port = 55000
          }

          env {
            name  = "INDEXER_URL"
            value = "https://wazuh-indexer-indexer:9200"
          }
          env {
            name  = "INDEXER_USERNAME"
            value = "admin"
          }
          env {
            name  = "INDEXER_PASSWORD"
            value = "admin"
          }
          env {
            name  = "FILEBEAT_SSL_VERIFICATION_MODE"
            value = "none"
          }

          resources {
            requests = {
              memory = "1Gi"
              cpu    = "500m"
            }
            limits = {
              memory = "2Gi"
              cpu    = "1000m"
            }
          }

          volume_mount {
            name       = "wazuh-manager"
            mount_path = "/var/ossec/data"
          }
        }
      }
    }

    volume_claim_template {
      metadata {
        name = "wazuh-manager"
      }
      spec {
        access_modes = ["ReadWriteOnce"]
        storage_class_name = "managed-premium"
        resources {
          requests = {
            storage = "10Gi"
          }
        }
      }
    }
  }

  depends_on = [kubernetes_stateful_set.wazuh_indexer]
}

# Wazuh Dashboard Service
resource "kubernetes_service" "wazuh_dashboard" {
  metadata {
    name      = "wazuh-dashboard"
    namespace = kubernetes_namespace.wazuh.metadata[0].name
  }
  spec {
    port {
      port        = 443
      target_port = 5601
      name        = "dashboard"
      protocol    = "TCP"
    }
    selector = {
      app = "wazuh-dashboard"
    }
  }
}

# Wazuh Dashboard Deployment
resource "kubernetes_deployment" "wazuh_dashboard" {
  metadata {
    name      = "wazuh-dashboard"
    namespace = kubernetes_namespace.wazuh.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "wazuh-dashboard"
      }
    }

    template {
      metadata {
        labels = {
          app = "wazuh-dashboard"
        }
      }

      spec {
        container {
          name  = "wazuh-dashboard"
          image = "wazuh/wazuh-dashboard:4.6.0"

          port {
            container_port = 5601
          }

          env {
            name  = "INDEXER_USERNAME"
            value = "admin"
          }
          env {
            name  = "INDEXER_PASSWORD"
            value = "admin"
          }
          env {
            name  = "WAZUH_API_URL"
            value = "https://wazuh-manager:55000"
          }
          env {
            name  = "API_USERNAME"
            value = "wazuh-wui"
          }
          env {
            name  = "API_PASSWORD"
            value = "MyS3cr37P450r.*-"
          }

          resources {
            requests = {
              memory = "512Mi"
              cpu    = "200m"
            }
            limits = {
              memory = "1Gi"
              cpu    = "500m"
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_stateful_set.wazuh_manager]
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
      target_port = 80
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

# Network policy for Wazuh namespace - FIXED VERSION
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