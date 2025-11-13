# SAP BTP Subscriptions - User Guide

## 🎯 What This Building Block Does

Subscribes your subaccount to SaaS applications available in the SAP BTP marketplace. These are turnkey applications you can start using immediately.

## 🚀 Quick Start

Add subscriptions by specifying apps in the format `app.plan`:

```
subscriptions = "build-workzone.standard,sapappstudio.standard-edition"
```

## 📋 Popular Applications

### Development Tools
- `sapappstudio.standard-edition` - Full-featured cloud IDE for SAP development
- `sap-build-apps.standard` - No-code/low-code app builder
- `cicd-service.default` - Continuous integration and deployment

### Integration & APIs
- `integrationsuite.enterprise_agreement` - API management, process integration, events
- `mobile-services.standard` - Mobile app development and management

### Collaboration
- `build-workzone.standard` - Digital workplace with sites, workspaces, and content

### Business Tools
- `business-rules.standard` - Business rules management
- `workflow.standard` - Workflow and process automation
- `web-analytics.standard` - Web analytics for apps

## 🔄 Shared Responsibility Matrix

| Responsibility | meshStack | App Team |
|---------------|-----------|----------|
| Select applications | | ✅ |
| Provision subscriptions | ✅ | |
| Configure applications | | ✅ |
| Manage application users | | ✅ |
| Application updates | SAP BTP | |
| Application support | SAP BTP | |

## 💡 Best Practices

### Check Entitlements First
Every subscription needs a matching entitlement. Use the **entitlements building block** first:
```
# Add entitlement first
entitlements = "sapappstudio.standard-edition"

# Then subscribe
subscriptions = "sapappstudio.standard-edition"
```

### Wait for Provisioning
Subscriptions can take 5-15 minutes to become ready. Check the BTP Cockpit for status.

### Start with Free/Trial Plans
Many apps offer free or trial plans:
- `build-workzone.free` - Free tier
- `sap-build-apps.free` - Free tier
- `cicd-service.trial` - Trial version

### Understand the Difference
- **Subscriptions** = SaaS apps (like Office 365)
- **Service Instances** = Platform services (like databases) → Use Cloud Foundry building block

## 🔍 Finding Available Apps

1. **BTP Cockpit**: Navigate to Subaccount → Services → Service Marketplace
2. **Filter by "Subscriptions"**: Shows only subscribable apps
3. **Check Prerequisites**: Some apps require other services

## ⚠️ Common Issues

### "Entitlement missing"
Add the required entitlement first using the entitlements building block.

### "Subscription takes forever"
Some subscriptions provision slowly. Wait 10-15 minutes, then check BTP Cockpit → Instances and Subscriptions.

### "Can't access the application"
After subscription:
1. Assign users to the application's role collections in BTP Cockpit
2. Access the app via the subscription URL (shown in BTP Cockpit)

### "Wrong plan selected"
Subscriptions can be changed by:
1. Updating the plan in your config
2. Running `tofu apply`
Note: Some plan changes may cause service interruption.

## 📞 Accessing Your Applications

After subscription:
1. Go to BTP Cockpit → Subaccount → Instances and Subscriptions
2. Find your application
3. Click "Go to Application" link
4. Log in with your SAP BTP user credentials

## 🎓 Next Steps

1. **Assign Users**: Configure role collections for your team
2. **Configure Apps**: Follow app-specific configuration guides
3. **Integrate**: Connect apps to your development workflow

## 📞 Getting Help

- Check SAP BTP Service Marketplace for app details
- Review app documentation in SAP Help Portal
- Contact platform team for subscription issues
