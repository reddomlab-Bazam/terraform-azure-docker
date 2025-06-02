# RedDome Lab - Infrastructure as Code Project

## 📚 Project Overview
This project implements a secure monitoring infrastructure using Terraform, Azure, Docker, and various monitoring tools. It's designed for educational purposes to help students understand modern DevSecOps practices.

## 🏗 Architecture
The project consists of several interconnected components:
- Azure Infrastructure (managed by Terraform)
- Monitoring Stack (Wazuh, Grafana)
- Cloudflare for secure access
- Container orchestration with Docker

## 📁 Directory Structure
```
terraform-azure-docker/
├── modules/
│   └── monitoring/
│       └── values/
│           └── cloudflare-values.yaml
└── [other project files]
```

## 🔧 Component Explanations

### Cloudflare Configuration (cloudflare-values.yaml)
This YAML file configures the Cloudflare tunnel and ingress settings for secure access to monitoring services.

Key components:
- **Tunnel Configurations**: Each service has its own secure tunnel to Cloudflare
- **Ingress Rules**: Traffic is isolated per service
  - Wazuh Dashboard: Dedicated tunnel for security monitoring
  - Grafana: Separate tunnel for metrics access

Variables explained:
- `${CLOUDFLARE_TUNNEL_TOKEN_GRAFANA}`: Grafana-specific tunnel token
- `${CLOUDFLARE_TUNNEL_TOKEN_WAZUH}`: Wazuh-specific tunnel token
- `${WAZUH_SUBDOMAIN}`: Subdomain for accessing Wazuh dashboard
- `${DOMAIN_NAME}`: Your main domain name
- `${GRAFANA_SUBDOMAIN}`: Subdomain for accessing Grafana

## 🚀 Setup Instructions

### 1. Prerequisites
- Terraform installed
- Azure CLI configured
- Cloudflare account
- Docker installed

### 2. Terraform Cloud Variables
Before deploying, set up the following variables in your Terraform Cloud workspace:

**Environment Variables (ALL SENSITIVE):**
```
ARM_CLIENT_ID       = "your-azure-client-id"
ARM_CLIENT_SECRET   = "your-azure-client-secret"
ARM_SUBSCRIPTION_ID = "your-azure-subscription-id"
ARM_TENANT_ID      = "your-azure-tenant-id"
```

**Terraform Variables:**
```
# Sensitive variables (mark as sensitive in Terraform Cloud)
grafana_admin_password          = "your-secure-password"
cloudflare_tunnel_token_grafana = "your-grafana-tunnel-token"
cloudflare_tunnel_token_wazuh   = "your-wazuh-tunnel-token"
api_authorized_ranges           = ["your-ip-ranges"]

# Non-sensitive variables
domain_name                = "your-domain.com"
environment               = "prd"
location                  = "uksouth"
wazuh_subdomain          = "wazuh"
grafana_subdomain        = "grafana"
```

### 3. Configuration Steps

a. Initialize Terraform:
```bash
terraform init
```

b. Apply the configuration:
```bash
terraform apply
```

## 🔐 Security Considerations
The configuration includes several security features:
- HTTP2 protocol enabled
- TLS verification
- Security headers configured
- Resource limits defined

## 🔄 How Components Work Together

1. **Traffic Flow**:
   ```
   Internet → Cloudflare → Tunnel → Internal Services
   ```

2. **Service Access**:
   - Wazuh: `https://wazuh.your-domain.com`
   - Grafana: `https://grafana.your-domain.com`

3. **Resource Management**:
   - CPU and memory limits are predefined
   - Requests: 100m CPU, 128Mi memory
   - Limits: 200m CPU, 256Mi memory

## 🛠 Troubleshooting

Common issues and solutions:
1. Tunnel Connection Issues:
   - Verify token is correct
   - Check network connectivity
   - Ensure service ports are correct

2. Service Access Problems:
   - Verify DNS records in Cloudflare
   - Check ingress configurations
   - Confirm service is running

## 📝 Notes for Students
- Always backup configurations before making changes
- Use version control for tracking changes
- Test in a development environment first
- Monitor resource usage to adjust limits if needed

## 🆘 Support
For issues or questions:
1. Check the troubleshooting guide
2. Review Cloudflare and Azure documentation
3. Consult with your instructor
4. Open an issue in the project repository

## 🔄 Updates and Maintenance
Regular maintenance tasks:
- Update Terraform providers
- Review security configurations
- Monitor resource usage
- Update documentation as needed
