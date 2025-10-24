# Azure Virtual Machine

## Description
An Azure Virtual Machine (VM) is an on-demand, scalable computing resource that provides the flexibility of virtualization without the need to buy and maintain physical hardware. Azure VMs support both Linux and Windows operating systems and can be configured with various sizes and capabilities to meet specific workload requirements.

Key features include:
- **Flexible Sizing**: Choose from a wide range of VM sizes optimized for different workloads (general purpose, compute-intensive, memory-optimized, etc.)
- **Multiple OS Support**: Run Linux distributions or Windows Server
- **Managed Disks**: Persistent storage for OS and data with various performance tiers
- **Network Isolation**: Deploy VMs in virtual networks with network security groups for enhanced security
- **Managed Identity**: System-assigned identities for secure authentication to Azure services without storing credentials

## Usage Motivation
This building block provisions Azure Virtual Machines to provide isolated, dedicated compute resources for various workloads. VMs are ideal when you need:
- Full control over the operating system and software stack
- Ability to install custom applications or legacy software
- Dedicated compute resources with predictable performance
- Migration of on-premises workloads to the cloud (lift-and-shift)

## Usage Examples

### Development and Testing Environments
Deploy VMs for development teams to create isolated environments for building and testing applications. Each team can have their own VM with specific configurations, tools, and dependencies without affecting other teams.

### Application Hosting
Host web applications, APIs, or microservices on VMs when containerization isn't feasible or when you need full OS control. The VM can run application servers like Apache, Nginx, IIS, or custom software stacks.

### Database Servers
Deploy VMs to host database management systems like PostgreSQL, MySQL, SQL Server, or MongoDB when managed database services don't meet specific requirements or when migrating existing database installations.

### Build and CI/CD Agents
Use VMs as build agents for CI/CD pipelines, providing isolated environments for compiling code, running tests, and creating deployment artifacts.

### Data Processing
Deploy VMs for batch processing jobs, data transformation tasks, or computational workloads that require specific software or configurations.

## Shared Responsibility

| Responsibility          | Platform Team | Application Team |
|------------------------|--------------|----------------|
| Provisioning and configuring VM infrastructure | ✅ | ❌ |
| Managing virtual networks and subnets | ✅ | ❌ |
| Providing secure access methods (Bastion, VPN) | ✅ | ❌ |
| Installing and configuring applications | ❌ | ✅ |
| Managing OS updates and patches | ❌ | ✅ |
| Configuring firewall rules and NSG policies | ✅ | ⚠️ (within team's NSG) |
| Backup and disaster recovery configuration | ⚠️ | ✅ |
| Monitoring application performance | ❌ | ✅ |
| Managing user access and SSH keys | ❌ | ✅ |

## VM Size Selection Guide

Choose the appropriate VM size based on your workload requirements:

| VM Series | Use Case | Example Sizes |
|-----------|----------|---------------|
| **B-Series** | Burstable, cost-effective for low CPU utilization | B1s, B2s, B2ms |
| **D-Series** | General purpose, balanced CPU-to-memory | D2s_v3, D4s_v3, D8s_v3 |
| **E-Series** | Memory-optimized, high memory-to-CPU ratio | E4s_v3, E8s_v3, E16s_v3 |
| **F-Series** | Compute-optimized, high CPU-to-memory ratio | F4s_v2, F8s_v2, F16s_v2 |

Start with smaller sizes (e.g., B2s for dev/test) and scale up as needed.

## Recommendations for Secure and Efficient VM Usage

### Security Best Practices
- **Avoid Public IPs**: Use Azure Bastion or VPN for remote access instead of exposing VMs to the internet
- **Use SSH Keys**: For Linux VMs, always use SSH key authentication instead of passwords
- **Strong Passwords**: For Windows VMs, use complex passwords and consider Azure AD integration
- **Managed Identity**: Leverage system-assigned managed identities to authenticate to Azure services
- **Network Security Groups**: Configure NSG rules to allow only necessary traffic
- **Regular Updates**: Keep the OS and applications updated with the latest security patches
- **Azure Security Center**: Enable for security recommendations and threat detection

### Performance and Cost Optimization
- **Right-Size VMs**: Monitor resource utilization and adjust VM size accordingly
- **Use Premium SSD**: For production workloads requiring consistent performance
- **Spot Instances**: Enable spot instances for dev/test and non-critical workloads to save up to 90% on costs
  - Be aware that spot VMs can be evicted when Azure needs capacity
  - Best for stateless workloads and batch processing
  - Not suitable for production or databases with local data
- **Reserved Instances**: Purchase reserved instances for long-running production VMs to save costs
- **Auto-Shutdown**: Configure automatic shutdown schedules for non-production VMs
- **Azure Hybrid Benefit**: Use existing Windows Server licenses to reduce costs

### Operational Best Practices
- **Backup Strategy**: Implement regular backups using Azure Backup
- **Monitoring**: Enable Azure Monitor and configure alerts for critical metrics
- **Tagging**: Apply consistent tags for cost tracking and resource management
- **Documentation**: Document VM purpose, configurations, and dependencies
- **Disaster Recovery**: Plan for disaster recovery with Azure Site Recovery if needed

### Data Disk Best Practices
- **Separate OS and Data**: Use separate data disks for application data
- **Choose Right Storage Type**: Use Premium SSD for I/O intensive workloads, Standard SSD for regular workloads
- **Plan Disk Size**: Provision appropriate disk size upfront as resizing requires downtime

## Getting Started

### For Linux VMs
1. Generate an SSH key pair if you don't have one: `ssh-keygen -t rsa -b 4096`
2. Request VM provisioning with your public key
3. Connect via SSH: `ssh azureuser@<private-ip>`
4. Install required software and configure your application

### For Windows VMs
1. Request VM provisioning with a secure password
2. Connect via Azure Bastion or RDP
3. Configure Windows features and install required software
4. Set up your application and services

## Support and Troubleshooting

Common issues and solutions:
- **Cannot connect to VM**: Verify NSG rules allow traffic and check if VM is running
- **Slow performance**: Check VM metrics in Azure Monitor, consider scaling up or optimizing workload
- **Disk full**: Monitor disk usage and attach additional data disks or resize existing disks
- **Application errors**: Check VM logs, event viewer (Windows), or system logs (Linux)

For additional support, contact the Platform Team.
