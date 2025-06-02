# RedDome Lab - Student Exercises

## Exercise 1: Security Assessment

**Objective**: Perform a security assessment of the RedDome Lab infrastructure.

**Tasks**:
1. Review network security configuration in Azure
   - Examine NSG rules
   - Analyze firewall configurations
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

## Exercise 3: Disaster Recovery Testing

**Objective**: Implement and test disaster recovery procedures.

**Tasks**:
1. Configure Velero backup schedules
   - Set up daily backups of critical namespaces
   - Configure retention policies
   - Verify backup storage

2. Perform a controlled disaster scenario
   - Delete a critical service
   - Execute recovery procedures
   - Document recovery time

3. Create an automated recovery script
   - Write a script to detect and recover from failures
   - Test the script against various failure scenarios
   - Measure recovery effectiveness

**Deliverable**: Disaster recovery plan with tested procedures