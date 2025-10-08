# IONOS DCD Environment

Welcome to your new IONOS Data Center Designer (DCD) environment! This guide will help you get started with managing your cloud infrastructure.

## What's Been Created

✅ **IONOS Datacenter**: A new DCD environment in **{{ datacenter_location }}**  
✅ **User Accounts**: Individual accounts for each team member  
✅ **Access Groups**: Role-based groups with appropriate permissions  
✅ **Resource Sharing**: Datacenter access configured for your team  

## Access Your Environment

1. **Login to IONOS DCD**: [https://dcd.ionos.com](https://dcd.ionos.com)
2. **Use your credentials**:
   - Email: Your work email address
   - Password: Provided by your administrator (please change on first login)
3. **Enable 2FA**: Set up two-factor authentication for enhanced security

## Your Access Level

Based on your assigned roles, you have access to:

### Readers 👀
- View datacenter resources and configurations
- Access monitoring and activity logs
- Read-only access to all resources

### Users 🔧  
- Create and manage virtual machines
- Configure networks and storage
- Create snapshots and backups
- Manage IP addresses

### Administrators 🛡️
- Full datacenter management
- Create additional datacenters
- Manage user permissions
- Configure advanced networking (PCC, K8s)

## Quick Start Guide

### 1. First Login
- Change your initial password
- Set up two-factor authentication
- Explore the DCD interface

### 2. Create Your First Server
1. Navigate to "Compute" → "Servers"
2. Click "Create Server"
3. Select your preferred OS template
4. Configure CPU, RAM, and storage
5. Assign to your network

### 3. Network Configuration
1. Go to "Network" → "LANs"
2. Create or modify existing networks
3. Configure firewall rules
4. Assign IP addresses

## Important Information

- **Datacenter Name**: {{ datacenter_name }}
- **Location**: {{ datacenter_location }}
- **Resource Limits**: Contact your administrator for quota increases
- **Backup Schedule**: Configure automatic backups for critical systems
- **Monitoring**: Use the built-in monitoring tools to track resource usage

## Need Help?

- **IONOS Documentation**: [https://docs.ionos.com](https://docs.ionos.com)
- **DCD User Guide**: Available in the DCD interface under "Help"
- **Support**: Contact your system administrator or IONOS support

## Best Practices

✅ **Always use descriptive names** for your resources  
✅ **Tag your resources** for better organization  
✅ **Set up monitoring alerts** for critical systems  
✅ **Regular backups** of important data  
✅ **Follow security guidelines** provided by your organization  

---

**Note**: This environment is managed by Terraform. Manual changes may be overwritten during updates. Please coordinate with your infrastructure team for any configuration changes.