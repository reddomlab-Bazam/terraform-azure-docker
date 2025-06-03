# Azure Kubernetes Security Lab - Wazuh & Grafana Deployment

A comprehensive Terraform configuration for deploying a security monitoring stack on Azure Kubernetes Service (AKS) with Cloudflare tunnel integration for secure external access.

## 🏗️ Architecture Overview

This deployment creates a complete security monitoring infrastructure including:

- **🔐 Azure Kubernetes Service (AKS)**: Managed Kubernetes cluster with security best practices
- **🛡️ Wazuh SIEM**: Security Information and Event Management platform
- **📊 Grafana**: Metrics visualization and monitoring dashboards
- **📈 Prometheus**: Metrics collection and alerting
- **🌐 Cloudflare Tunnels**: Secure external access without exposing public IPs
- **🔒 Network Security**: NSGs, network policies, and proper RBAC

## 📁 Project Structure

```
terraform-azure-docker/
├── main.tf                     # Main Terraform configuration
├── variables.tf                # Variable definitions
├── outputs.tf                  # Output definitions
├── terraform.tfvars.template   # Template for variables
├── modules/
│   ├── aks/                    # AKS cluster configuration
│   ├── networking/             # VNet, subnets, NSGs
│   ├── monitoring/             # Grafana, Prometheus deployment
│   └── wazuh/                  # Wazuh SIEM deployment
└── README.md                   # This file
```

## 🚀 Quick Start Guide

### Prerequisites

1. **Azure Subscription** with appropriate permissions
2. **Terraform Cloud** account (recommended for state management)
3. **Cloudflare Account** with Zero Trust enabled
4. **Azure CLI** installed and configured
5. **kubectl** installed for cluster management

### Step 1: Azure Setup

#### Create Service Principal
```bash
# Login to Azure
az login

# Create a service principal for Terraform
az ad sp create-for-rbac --name "terraform-azure-docker" --role="Contributor" --scopes="/subscriptions/YOUR_SUBSCRIPTION_ID"
```

#### Create Log Analytics Workspace
```bash
# Create resource group for monitoring
az group create --name "rg-monitoring-prd" --location "uksouth"

# Create Log Analytics workspace
az monitor log-analytics workspace create \
    --resource-group "rg-monitoring-prd" \
    --workspace-name "law-monitoring-prd" \
    --location "uksouth"

# Get the workspace ID (needed for terraform.tfvars)
az monitor log-analytics workspace show \
    --resource-group "rg-monitoring-prd" \
    --workspace-name "law-monitoring-prd" \
    --query id -o tsv
```

### Step 2: Cloudflare Tunnel Setup

#### Create Tunnels in Cloudflare Dashboard

1. **Go to Cloudflare Zero Trust Dashboard** → Access → Tunnels
2. **Create Tunnel for Grafana**:
   - Name: `azure-grafana`
   - Copy the tunnel token
3. **Create Tunnel for Wazuh**:
   - Name: `azure-wazuh`
   - Copy the tunnel token

#### Configure DNS Records
```bash
# In Cloudflare DNS, create CNAME records:
grafana.yourdomain.com → azure-grafana.cfargotunnel.com
wazuh.yourdomain.com   → azure-wazuh.cfargotunnel.com
```

### Step 3: Terraform Cloud Configuration

#### Create Workspace
1. **Create new workspace**: `terraform-azure-docker`
2. **Connect to your Git repository**
3. **Configure the following variables**:

#### Environment Variables (Mark as Sensitive)
```bash
ARM_CLIENT_ID       = "your-service-principal-client-id"
ARM_CLIENT_SECRET   = "your-service-principal-secret"
ARM_SUBSCRIPTION_ID = "your-azure-subscription-id"
ARM_TENANT_ID      = "your-azure-tenant-id"

# Sensitive configuration variables
TF_VAR_grafana_admin_password          = "your-secure-grafana-password"
TF_VAR_cloudflare_tunnel_token_grafana = "your-grafana-tunnel-token"
TF_VAR_cloudflare_tunnel_token_wazuh   = "your-wazuh-tunnel-token"
TF_VAR_api_authorized_ranges           = ["203.0.113.0/24"]
```

#### Terraform Variables
```hcl
domain_name                    = "yourdomain.com"
environment                   = "prd"
location                      = "uksouth"
grafana_subdomain             = "grafana"
wazuh_subdomain              = "wazuh"
log_analytics_workspace_id   = "/subscriptions/.../law-monitoring-prd"
kubernetes_version           = "1.28.5"
node_count                   = 2
vm_size                      = "Standard_D2s_v3"
enable_monitoring            = true
```

### Step 4: Deploy Infrastructure

```bash
# Clone your repository
git clone <your-repo-url>
cd terraform-azure-docker

# Copy and configure variables
cp terraform.tfvars.template terraform.tfvars
# Edit terraform.tfvars with your values

# Initialize Terraform (if running locally)
terraform init

# Plan deployment
terraform plan

# Apply configuration
terraform apply
```

### Step 5: Verify Deployment

```bash
# Configure kubectl
az aks get-credentials --resource-group aks-uks-prd-rg --name aks-uks-prd

# Check cluster status
kubectl get nodes
kubectl get pods -A

# Check specific services
kubectl get pods -n monitoring
kubectl get pods -n wazuh
kubectl get services -n monitoring
kubectl get services -n wazuh
```

## 🔧 Service Access

### External Access (via Cloudflare Tunnels)
- **Grafana**: `https://grafana.yourdomain.com`
- **Wazuh**: `https://wazuh.yourdomain.com`

### Local Access (via Port Forwarding)
```bash
# Grafana
kubectl port-forward -n monitoring svc/grafana 3000:3000
# Access at: http://localhost:3000

# Wazuh Dashboard
kubectl port-forward -n wazuh svc/wazuh-dashboard 5601:443
# Access at: https://localhost:5601

# Prometheus
kubectl port-forward -n monitoring svc/prometheus-server 9090:80
# Access at: http://localhost:9090
```

### Default Credentials
- **Grafana**: `admin` / `[your-configured-password]`
- **Wazuh**: `admin` / `admin` (⚠️ **Change immediately after first login**)

## 🧪 Testing and Validation

### Test 1: Infrastructure Health
```bash
# Check all pods are running
kubectl get pods -A

# Check services are accessible
kubectl get svc -A

# Check persistent volumes
kubectl get pv
kubectl get pvc -A
```

### Test 2: Tunnel Connectivity
```bash
# Test external access
curl -I https://grafana.yourdomain.com
curl -I https://wazuh.yourdomain.com

# Should return 200 or redirect to login
```

### Test 3: Monitoring Stack Integration
```bash
# Check Grafana can connect to Prometheus
kubectl logs -n monitoring deployment/grafana

# Check Wazuh indexer status
kubectl logs -n wazuh statefulset/wazuh-indexer-indexer

# Verify Prometheus targets
kubectl port-forward -n monitoring svc/prometheus-server 9090:80
# Navigate to http://localhost:9090/targets
```

### Test 4: Security Policies
```bash
# Test network policies
kubectl get networkpolicies -A

# Test resource quotas
kubectl describe quota -n monitoring
kubectl describe quota -n wazuh

# Check security contexts
kubectl get pods -n wazuh -o jsonpath='{.items[*].spec.securityContext}'
```

## 🛠️ Customization

### Adding Custom Dashboards to Grafana

1. **Create ConfigMap with dashboard JSON**:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: custom-dashboard
  namespace: monitoring
data:
  dashboard.json: |
    {
      "dashboard": {
        "title": "Custom Dashboard",
        ...
      }
    }
```

2. **Mount to Grafana pod** in `modules/monitoring/main.tf`

### Scaling the Deployment

#### Horizontal Scaling
```bash
# Scale AKS nodes
az aks scale --resource-group aks-uks-prd-rg --name aks-uks-prd --node-count 3

# Scale individual deployments
kubectl scale deployment grafana --replicas=2 -n monitoring
```

#### Vertical Scaling
Update resource limits in `modules/monitoring/variables.tf`:
```hcl
variable "grafana_resources" {
  default = {
    requests = {
      cpu    = "500m"
      memory = "1Gi"
    }
    limits = {
      cpu    = "2000m"
      memory = "4Gi"
    }
  }
}
```

### Adding New Monitoring Services

1. **Create new deployment** in `modules/monitoring/main.tf`
2. **Add service configuration**
3. **Configure Cloudflare tunnel** if external access needed
4. **Add to Prometheus scrape config**

## 🚨 Troubleshooting

### Common Issues

#### 1. AKS Cluster Creation Fails
```bash
# Check Azure resource quotas
az vm list-usage --location uksouth

# Check service principal permissions
az role assignment list --assignee YOUR_CLIENT_ID
```

#### 2. Wazuh Deployment Issues
```bash
# Check namespace and resources
kubectl get ns wazuh
kubectl get pods -n wazuh
kubectl describe pod -n wazuh POD_NAME

# Check deployment script logs
cat modules/wazuh/deploy_wazuh.sh
```

#### 3. Grafana Can't Connect to Data Sources
```bash
# Check Grafana logs
kubectl logs -n monitoring deployment/grafana

# Verify service discovery
kubectl get svc -n wazuh
kubectl get endpoints -n wazuh

# Test connectivity from Grafana pod
kubectl exec -n monitoring deployment/grafana -- nslookup wazuh-indexer-indexer.wazuh.svc.cluster.local
```

#### 4. Cloudflare Tunnel Issues
```bash
# Check tunnel pod logs
kubectl logs -n monitoring -l app.kubernetes.io/name=cloudflared

# Verify tunnel tokens
kubectl get secret -n monitoring

# Test internal service connectivity
kubectl exec -n monitoring deployment/grafana -- curl -I http://localhost:3000
```

#### 5. Network Policy Blocking Traffic
```bash
# Check network policies
kubectl get networkpolicies -A

# Temporarily disable for testing
kubectl delete networkpolicy monitoring-network-policy -n monitoring

# Check Calico logs (if using Calico CNI)
kubectl logs -n kube-system -l k8s-app=calico-node
```

### Debug Commands

```bash
# Get comprehensive cluster info
kubectl cluster-info dump

# Check resource usage
kubectl top nodes
kubectl top pods -A

# Check events
kubectl get events -A --sort-by='.lastTimestamp'

# Check specific resource details
kubectl describe pod POD_NAME -n NAMESPACE
kubectl describe svc SERVICE_NAME -n NAMESPACE

# Check security contexts
kubectl get pods -o jsonpath='{.items[*].spec.securityContext}' -n NAMESPACE
```

## 🔐 Security Best Practices

### Infrastructure Security
- ✅ **Private AKS cluster** with API server IP restrictions
- ✅ **Network Security Groups** controlling subnet access
- ✅ **Network policies** for pod-to-pod communication
- ✅ **RBAC enabled** with proper service accounts
- ✅ **Azure Policy integration** for compliance
- ✅ **Microsoft Defender** for Kubernetes enabled

### Application Security
- ✅ **Non-root containers** with security contexts
- ✅ **Resource limits** to prevent resource exhaustion
- ✅ **Secrets management** via Kubernetes secrets
- ✅ **TLS encryption** for all communications
- ✅ **Regular security updates** via automated processes

### Access Security
- ✅ **Cloudflare tunnels** instead of public load balancers
- ✅ **Strong authentication** with complex passwords
- ✅ **Principle of least privilege** for all access
- ✅ **Audit logging** enabled for all components
- ✅ **Regular access reviews** and cleanup

## 📊 Monitoring and Alerting

### Key Metrics to Monitor

#### Infrastructure Metrics
- **Node CPU/Memory usage**
- **Pod resource consumption**
- **Persistent volume usage**
- **Network traffic patterns**

#### Application Metrics
- **Wazuh indexer performance**
- **Grafana response times**
- **Prometheus scrape targets**
- **Alert manager notifications**

#### Security Metrics
- **Failed authentication attempts**
- **Unusual network patterns**
- **Resource quota violations**
- **Security policy violations**

### Setting Up Alerts

1. **Configure Slack/Email notifications** in Prometheus AlertManager
2. **Set up Azure Monitor integration** for infrastructure alerts
3. **Configure Wazuh rules** for security events
4. **Create Grafana alerts** for application metrics

## 🔄 Backup and Disaster Recovery

### Automated Backups

#### Using Velero (Recommended)
```bash
# Install Velero
helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts/
helm install velero vmware-tanzu/velero -n velero --create-namespace

# Create backup schedule
kubectl apply -f - <<EOF
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: daily-backup
  namespace: velero
spec:
  schedule: "0 2 * * *"
  template:
    includedNamespaces:
    - monitoring
    - wazuh
    ttl: "720h"
EOF
```

#### Manual Backup Commands
```bash
# Backup monitoring namespace
velero backup create monitoring-backup --include-namespaces monitoring

# Backup Wazuh namespace
velero backup create wazuh-backup --include-namespaces wazuh

# List backups
velero backup get

# Restore from backup
velero restore create --from-backup monitoring-backup
```

### Disaster Recovery Procedures

1. **Infrastructure Recovery**:
   ```bash
   # Re-run Terraform
   terraform apply
   
   # Restore from backups
   velero restore create --from-backup BACKUP_NAME
   ```

2. **Data Recovery**:
   - Persistent volumes are backed up with Velero
   - Wazuh indices can be restored from snapshots
   - Grafana dashboards can be exported/imported

3. **Configuration Recovery**:
   - All configurations are in Terraform
   - Secrets should be restored from secure backup
   - DNS records in Cloudflare are preserved

## 📋 Production Deployment Checklist

### Pre-Deployment
- [ ] Azure subscription with appropriate quotas
- [ ] Service principal created with correct permissions
- [ ] Cloudflare domain and tunnels configured
- [ ] Log Analytics workspace created
- [ ] Terraform Cloud workspace configured
- [ ] All sensitive variables marked as sensitive
- [ ] Network security requirements documented
- [ ] Backup and recovery procedures tested

### Post-Deployment
- [ ] All pods running successfully
- [ ] External access via Cloudflare tunnels working
- [ ] Default passwords changed
- [ ] Monitoring and alerting configured
- [ ] Security policies validated
- [ ] Backup schedules configured
- [ ] Team access and training completed
- [ ] Documentation updated
- [ ] Incident response procedures established

## 📞 Support and Maintenance

### Regular Maintenance Tasks
- **Weekly**: Review security alerts and logs
- **Monthly**: Update Kubernetes and application versions
- **Quarterly**: Review and update security policies
- **Annually**: Rotate secrets and certificates

### Getting Help
1. **Check the troubleshooting section** in this README
2. **Review Terraform and Kubernetes logs**
3. **Consult Azure AKS documentation**
4. **Check Wazuh and Grafana official documentation**
5. **Open issues in the project repository**

### Version Updates
```bash
# Update Terraform providers
terraform init -upgrade

# Update Helm charts
helm repo update
helm upgrade grafana prometheus-community/grafana -n monitoring

# Update Kubernetes version
az aks upgrade --resource-group aks-uks-prd-rg --name aks-uks-prd --kubernetes-version 1.29.0
```

---

**🎯 Ready to deploy enterprise-grade security monitoring on Azure!**

This infrastructure provides a robust, scalable, and secure foundation for security monitoring and incident response training.