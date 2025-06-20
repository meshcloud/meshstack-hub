Provides an on-premise connected VNet for your Azure subscription.

This building block simplifies the creation of Azure Virtual Networks (VNets) with secure and reliable connectivity to your on-premise environment. It's designed for application teams that require seamless access to on-premise resources from their Azure-based applications.

**Usage Motivation**

This building block is ideal for:

*   Teams migrating applications to Azure that have dependencies on on-premise systems.
*   Applications requiring real-time data access from on-premise databases or services.
*   Establishing a hybrid cloud environment for development, testing, or disaster recovery.

**Usage Examples**

1.  A developer deploys a web application in Azure that needs to access an on-premise database for user authentication and data retrieval. The 'On-Premise Connectivity' building block provides the secure network connection for this communication.
2.  A data science team wants to train machine learning models using data stored both in Azure and on-premise. This building block enables them to access the necessary data sources seamlessly.

**Shared Responsibility**

| Responsibility          | Platform Team ✅ | Application Team ❌ |
| ------------------------- | --------------- | --------------- |
| Network Security          | ✅              | ❌              |
| On-Premise Connectivity SLA | ✅              | ❌              |
| VNet Management         | ✅              | ❌              |
| Resource Hookup           | ❌              | ✅              |
| Traffic Monitoring        | ✅              | ❌              |
| Traffic Management/QoS     | ✅              | ⚠️  (Mindful of Traffic)            |

**Important Considerations**

*   The platform team guarantees a 99.9% SLA for on-premise connectivity.
*   Application teams should be mindful of the amount of traffic traversing the on-premise connection due to the current 10G circuit limitation. Quality of Service (QoS) may be applied to rate limit excessive traffic.