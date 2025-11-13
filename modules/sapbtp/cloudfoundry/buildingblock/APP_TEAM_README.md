# SAP BTP Cloud Foundry - User Guide

## 🎯 What This Building Block Does

Enables Cloud Foundry - a platform for deploying and running cloud-native applications. Think of it as your application runtime with built-in services like databases and message queues.

## 🚀 Quick Start

### Enable Cloud Foundry Environment
```
cloudfoundry_plan = "standard"
```

### Add Services Your App Needs
```
cf_services = "postgresql.small,redis.medium,xsuaa.application"
```

## 📋 What is Cloud Foundry?

Cloud Foundry is a **Platform as a Service (PaaS)** that:
- Runs your applications (Node.js, Java, Python, Go, etc.)
- Automatically handles scaling, health checks, and restarts
- Provides built-in services (databases, caching, authentication)
- Simplifies deployment with `cf push`

## 🗄️ Available Services

### Databases
- **PostgreSQL**: Relational database
  - `postgresql.small` - 5GB storage, good for development
  - `postgresql.medium` - 20GB storage, good for production
  - `postgresql.large` - 100GB storage, high-performance

- **Redis**: In-memory cache
  - `redis.small` - 250MB, session storage
  - `redis.medium` - 1GB, general caching
  - `redis.large` - 5GB, high-traffic apps

### Authentication & Authorization
- **XSUAA**: User authentication and authorization
  - `xsuaa.application` - Most common, for app security
  - `xsuaa.broker` - For service brokers

### Connectivity
- **Destination**: Connect to remote systems
  - `destination.lite` - Free tier, destination management

- **Connectivity**: Connect to on-premise systems
  - `connectivity.lite` - Cloud Connector integration

### Developer Tools
- **Application Logs**: Centralized logging
  - `application-logs.lite` - Free tier
  - `application-logs.standard` - Production tier

- **Job Scheduler**: Run scheduled background jobs
  - `jobscheduler.lite` - Free tier
  - `jobscheduler.standard` - Production tier

### Storage & Secrets
- **Credential Store**: Secure secret management
  - `credstore.free` - Free tier
  - `credstore.standard` - Production tier

- **Object Store**: S3-compatible storage
  - `objectstore.s3-standard` - File storage

### UI Services
- **HTML5 Application Repository**: Host HTML5 apps
  - `html5-apps-repo.app-host` - Host apps
  - `html5-apps-repo.app-runtime` - Serve apps

## 🔄 Shared Responsibility Matrix

| Responsibility | meshStack/Platform | App Team |
|---------------|-------------------|----------|
| Provision CF environment | ✅ | |
| Create service instances | ✅ | |
| Deploy applications | | ✅ |
| Bind services to apps | | ✅ |
| Monitor applications | | ✅ |
| Scale applications | | ✅ |
| CF runtime updates | SAP BTP | |
| Service instance backups | SAP BTP | |

## 💡 Best Practices

### Start Small, Scale Up
```
# Development
cf_services = "postgresql.small,redis.small"

# Production (upgrade later)
cf_services = "postgresql.medium,redis.medium"
```

### Include Essential Services
Most apps need at least:
```
cf_services = "postgresql.small,xsuaa.application,destination.lite"
```

### Understand Service Plans
- **Free/Lite**: Limited, good for development, may have usage caps
- **Small**: Low traffic production apps
- **Medium**: Standard production apps
- **Large**: High-traffic or data-intensive apps

### Check Entitlements First
Each CF service needs a matching entitlement. Add via **entitlements building block**.

## 🚢 Deploying Your First App

After CF is provisioned:

1. **Install CF CLI**:
   ```bash
   # Download from https://github.com/cloudfoundry/cli
   ```

2. **Login to Cloud Foundry**:
   ```bash
   cf login -a https://api.cf.eu10.hana.ondemand.com
   # Enter your BTP credentials
   ```

3. **Target Your Org and Space**:
   ```bash
   cf orgs  # List available orgs
   cf target -o "your-org-name" -s "dev"
   ```

4. **Deploy Your App**:
   ```bash
   cf push my-app
   ```

5. **Bind Services**:
   ```bash
   cf bind-service my-app postgresql-small
   cf restage my-app
   ```

## 🔍 Checking Service Status

```bash
# List service instances
cf services

# Get service credentials
cf service-key postgresql-small my-key

# View service details
cf service postgresql-small
```

## ⚠️ Common Issues

### "CF environment not ready"
CF provisioning takes 10-20 minutes. Check status in BTP Cockpit.

### "Service not found"
1. Ensure entitlement exists (use entitlements building block)
2. Wait a few minutes after creating service instance
3. Check service marketplace: `cf marketplace`

### "Out of memory"
Your app needs more memory. Update manifest.yml:
```yaml
memory: 1G  # Increase from default 256M
```

### "Can't connect to service"
1. Verify service is bound: `cf services`
2. Check `VCAP_SERVICES` environment variable: `cf env my-app`
3. Restage app after binding: `cf restage my-app`

## 🎓 Next Steps

1. **Deploy an App**: Use `cf push` to deploy your application
2. **Bind Services**: Connect your app to databases and services
3. **Monitor**: Use `cf logs` and Application Logs service
4. **Scale**: Use `cf scale` to adjust instances and memory
5. **Automate**: Set up CI/CD with manifest.yml

## 📚 Learn More

- **CF CLI Cheatsheet**: https://docs.cloudfoundry.org/cf-cli/
- **SAP BTP CF Docs**: https://help.sap.com/docs/btp/sap-business-technology-platform/cloud-foundry-environment
- **Manifest.yml Guide**: https://docs.cloudfoundry.org/devguide/deploy-apps/manifest.html

## 📞 Getting Help

- Check CF logs: `cf logs my-app --recent`
- View app health: `cf apps`
- Contact platform team for infrastructure issues
- Use `cf help` for CLI command reference
