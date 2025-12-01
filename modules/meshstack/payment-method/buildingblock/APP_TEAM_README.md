# meshStack Payment Method

## Description
This building block provides a payment method for a specific workspace in meshStack. It allows teams to manage budgets and track spending across their cloud resources by assigning payment methods with defined amounts.

## Usage Motivation
This building block is for application teams managing workloads across multiple cloud platforms who need centralized cost control. Configuring a payment method enables teams to allocate budgets per workspace and ensure financial accountability.

## Usage Examples
- A development team creates a payment method with a budget of $10,000 for their workspace to control cloud spending.
- A team launching a new project sets up a payment method with an expiration date to align with their project timeline.
- An operations team assigns a payment method with custom tags to categorize and track spending by department or cost center.

## Shared Responsibility

| Responsibility          | Platform Team | Application Team |
|------------------------|--------------|----------------|
| Creating and maintaining automation for payment methods | ✅ | ❌ |
| Provisioning payment methods for workspaces | ✅ | ❌ |
| Configuring the budget amount | ❌ | ✅ |
| Managing expiration dates | ❌ | ✅ |
| Applying tags for cost tracking | ❌ | ✅ |
| Monitoring spending against the payment method | ❌ | ✅ |

## Recommendations for Setting the Right Budget
To define an effective payment method budget:
- **Baseline your spending**: Review historical costs across all platforms to determine a reasonable budget.
- **Add buffer**: Include a buffer (10-20%) for unexpected usage spikes.
- **Set expiration dates**: For temporary projects, set expiration dates to automatically clean up unused payment methods.
- **Use tags effectively**: Apply consistent tags to enable better cost tracking and reporting across your organization.
