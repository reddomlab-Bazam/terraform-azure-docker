# RedDome Lab - Architecture Overview

## Network Flow
Internet → Cloudflare → Tunnels → Azure Firewall → AKS Cluster → Monitoring Services

## Security Architecture

### Perimeter Security
- Cloudflare tunnels for secure external access
- Azure Firewall filtering all inbound/outbound traffic
- Network Security Groups controlling subnet access

### Cluster Security
- Private AKS cluster with API server IP restrictions
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
- Velero for backup and disaster recovery
- Resource limits configured to ensure stability

## Components Diagram
+----------------+      +----------------+      +----------------+
|                |      |                |      |                |
|   Internet     +----->+   Cloudflare   +----->+  Azure Firewall|
|                |      |                |      |                |
+----------------+      +----------------+      +-------+--------+
|
v
+--------+--------+
|                 |
|   AKS Cluster   |
|                 |
+--------+--------+
|
+------------------------+--+--+------------------------+
|                        |     |                        |
+------v------+          +------v-----+           +------------v---+
|             |          |            |           |                |
|   Wazuh     |          |  Grafana   |           |  Prometheus    |
|             |          |            |           |                |
+-------------+          +------------+           +----------------+
