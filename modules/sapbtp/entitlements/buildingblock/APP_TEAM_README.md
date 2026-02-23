# SAP BTP Entitlements - User Guide

## 🎯 What This Building Block Does

Enables access to SAP BTP platform services in your subaccount. Think of entitlements as "unlocking" services you want to use.

## 🚀 Quick Start

Add entitlements by specifying services in the format `service.plan`:

```
entitlements = "destination.lite,xsuaa.application,postgresql-db.trial"
```

## 📋 Common Services

### Authentication & Authorization
- `xsuaa.application` - User authentication and authorization
- `xsuaa.broker` - Service broker authentication

### Connectivity
- `destination.lite` - Destination management (free tier)
- `connectivity.lite` - On-premise connectivity (free tier)

### Databases
- `postgresql-db.trial` - PostgreSQL database (free tier)
- `postgresql-db.small` - PostgreSQL database (production)
- `redis-cache.small` - Redis cache

### Development Tools
- `sapappstudio.standard-edition` - SAP Business Application Studio IDE
- `sap-build-apps.standard` - Low-code development platform

### Cloud Foundry
- `cloudfoundry.standard` - Cloud Foundry environment
- `APPLICATION_RUNTIME.MEMORY` - Cloud Foundry application runtime memory

### Monitoring
- `auditlog-viewer.free` - View audit logs

## 🔄 Shared Responsibility Matrix

| Responsibility | meshStack | App Team |
|---------------|-----------|----------|
| Select required services | | ✅ |
| Configure service quotas | | ✅ |
| Provision entitlements | ✅ | |
| Monitor quota usage | | ✅ |
| Request quota increases | | ✅ |
| Service availability | SAP BTP | |

## 💡 Best Practices

### Start Small
Begin with trial or lite plans, upgrade when needed:
```
entitlements = "postgresql-db.trial,destination.lite"
```

### Group Related Services
Add all services needed for your application stack:
```
entitlements = "cloudfoundry.standard,APPLICATION_RUNTIME.MEMORY,xsuaa.application,destination.lite,postgresql-db.small"
```

### Know Your Quotas
Some services have quotas (like `APPLICATION_RUNTIME.MEMORY` = GB of RAM), others are boolean (enabled/disabled).

### Check Prerequisites
Some services require other entitlements:
- Cloud Foundry services need `cloudfoundry.standard` entitlement
- Many apps need `xsuaa.application` for authentication

## 🔍 Finding Available Services

1. **BTP Cockpit**: Navigate to Subaccount → Entitlements → Configure Entitlements
2. **Service Marketplace**: View all available services and their plans
3. **Documentation**: Check SAP BTP service catalog

## ⚠️ Common Issues

### "Service not available in region"
Some services are region-specific. Ensure your subaccount region supports the service.

### "Quota exceeded"
You've reached the quota limit. Either:
- Remove unused resources
- Request a quota increase
- Upgrade to a higher plan

### "Entitlement dependency missing"
Some services depend on others. For example:
- `postgresql-db.*` in Cloud Foundry requires `cloudfoundry.standard` entitlement

## 📞 Getting Help

- Check SAP BTP Service Catalog for service details
- Review quota usage in BTP Cockpit → Subaccount → Entitlements
- Contact platform team for quota increase requests
