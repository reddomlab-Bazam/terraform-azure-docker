# RedDome Lab - Student Instructions

## Overview
This lab provides hands-on experience with a modern DevSecOps monitoring stack running on Azure Kubernetes Service (AKS). You'll work with Wazuh for security monitoring, Grafana for visualization, and secure the deployment with Cloudflare tunnels.

## Getting Started

### 1. Access Your Environment
- Grafana Dashboard: https://grafana.your-domain.com
- Wazuh Dashboard: https://wazuh.your-domain.com

Default credentials are provided by your instructor.

### 2. Lab Environment Components
- AKS Cluster with Azure CNI networking and Calico network policy
- Wazuh security monitoring platform
- Grafana metrics visualization
- Prometheus metrics collection
- Velero for backup and disaster recovery
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

4. **Disaster Recovery**
   - Configure a Velero backup schedule
   - Perform a test backup and restore

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