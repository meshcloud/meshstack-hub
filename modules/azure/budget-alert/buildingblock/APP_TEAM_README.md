# Azure Budget Alert

## Description
This building block provides a budget alert for an Azure subscription. It helps teams monitor cloud spending and avoid unexpected cost overruns by setting up automated budget alerts.

## Usage Motivation
This building block is for application teams managing workloads in Azure who need to ensure cost control. Configuring a budget alert is mandatory to prevent accidental cloud costs.

## Usage Examples
- A development team sets a budget alert at 80% of their allocated monthly Azure budget to take proactive measures before exceeding limits.
- A team launching a new service uses a budget alert to monitor increased costs due to auto-scaling.

## Shared Responsibility

| Responsibility          | Platform Team | Application Team |
|------------------------|--------------|----------------|
| Creating and maintaining automation for budget alerts | ✅ | ❌ |
| Provisioning budget alerts for Azure subscriptions | ✅ | ❌ |
| Configuring the budget threshold | ❌ | ✅ |
| Adjusting alerts based on project needs | ❌ | ✅ |
| Monitoring and responding to alerts | ❌ | ✅ |

## Recommendations for Setting the Right Alert Threshold
To define an effective budget alert threshold:
- **Baseline your spending**: Review past Azure costs to determine a reasonable budget.
- **Use percentage-based alerts**: A common practice is setting alerts at 50%, 80%, and 100% of the budget.
- **Align with stakeholders**: Consult finance and leadership to ensure alerts align with cost expectations.
- **Adjust dynamically**: Review and update the threshold regularly based on usage patterns.
