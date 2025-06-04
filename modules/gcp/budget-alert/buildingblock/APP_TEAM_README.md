This building block sets up a GCP budget alert on your account and is intended for teams managing GCP workloads who want to avoid accidental overspending by proactively monitoring cloud costs.

## 🚀 Usage Example

A development team sets up a GCP budget alert to **receive notifications** when their monthly GCP spend exceeds 80% of their allocated budget.

You can customize when alerts are triggered by providing a YAML string to the `alert_thresholds_yaml` input variable. Each entry specifies a percentage threshold and whether it applies to actual or forecasted spend.

**Example input:**
```yaml
- percent: 80
  basis: ACTUAL
- percent: 100
  basis: FORECASTED
```

- `percent`: The percentage of the budget that will trigger an alert (e.g., `80` for 80%).
- `basis`: Whether the alert is based on `ACTUAL` spend or `FORECASTED` spend.

This allows you to receive notifications both when your actual spend reaches a certain threshold and when your forecasted spend is projected to exceed your budget.

## 🔄 Shared Responsibility

| Responsibility        | Platform Team ✅ | Application Team ✅/❌ |
|----------------------|----------------|------------------|
| Provides automation for GCP Budget setup | ✅ | ❌ |
| Manages alert delivery mechanism (e.g., Pub/Sub, email) | ✅ | ❌ |
| Defines the budget threshold | ❌ | ✅ |
| Adjusts alerts based on cost trends | ❌ | ✅ |

## 💡 Best Practices for Choosing a Budget Threshold
To set an effective budget alert:
- Start with **historical GCP spend** as a baseline.
- Set alerts at **80% and 95% of the budget** to allow for proactive adjustments.
- Consider **seasonal or usage-based variations** in cloud costs.
- Use **multiple alerts** (e.g., per service, per team) if necessary to get granular insights.

---
Would you like to include specific details about notification methods (e.g., email, Slack, Pub/Sub, etc.) or tie this into your overall cloud governance policies? Let me know if you want refinements! 🚀
