resource "kubernetes_namespace" "wazuh" {
  metadata {
    name = "wazuh"
  }
}

# For Wazuh, we'll need to create a script that will run kubectl commands
# This will be executed when the cluster is accessible
resource "local_file" "deploy_wazuh_script" {
  filename = "${path.module}/deploy_wazuh.sh"
  content = <<-EOT
    #!/bin/bash
    set -e
    
    # Clone the official Wazuh Kubernetes repository
    git clone https://github.com/wazuh/wazuh-kubernetes.git -b v4.5.1 --depth=1
    cd wazuh-kubernetes
    
    # Apply the Kubernetes manifests
    kubectl apply -f wazuh/base/
    kubectl apply -f wazuh/indexer_stack/
    kubectl apply -f wazuh/manager/
  EOT
}

# We'll create a placeholder until we can manually run the script
resource "null_resource" "wazuh_placeholder" {
  depends_on = [kubernetes_namespace.wazuh]

  # This is just a placeholder since we can't execute kubectl directly
  # The script will need to be manually executed when the cluster is ready
  provisioner "local-exec" {
    command = "echo 'To deploy Wazuh, run the deploy_wazuh.sh script when the cluster is accessible with kubectl'"
  }
}