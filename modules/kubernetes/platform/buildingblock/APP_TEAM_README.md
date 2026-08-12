This building block connects a Kubernetes cluster to meshStack, so that teams can order a namespace
on it from the marketplace. It creates the service accounts meshStack authenticates with inside the
cluster, registers the cluster as a platform, and adds one landing zone per environment with its own
quotas. After it runs, meshStack replicates every tenant of the platform into a namespace on the
cluster and keeps the role bindings in sync with the project roles.

## 🎯 When to use it

Use this building block when you:

- run a Kubernetes cluster and want to hand out namespaces on it through meshStack instead of by hand
- want project roles in meshStack to drive `admin`, `edit` and `view` access inside the namespace
- want meshStack to enforce CPU, memory and storage quotas per namespace
- want usage data from the cluster to reach meshMetering for chargeback

Do not use it for AKS. meshStack models AKS namespace platforms with a different configuration and an
Entra service principal, so AKS needs its own registration module.

## 💡 Usage examples

**Example 1: Opening a new cluster to the marketplace**
Your team has just finished a STACKIT Kubernetes Engine cluster and wants application teams to be able
to order namespaces on it. You order this building block with the cluster's API server URL and its
credentials. Application teams then see a `dev` and a `prod` landing zone in the marketplace and can
order a namespace on either.

**Example 2: Tightening the quotas on a small cluster**
Your cluster is smaller than the defaults assume, so you want half the CPU and memory per namespace.
You order the building block with your own `quota_definitions` and `landing_zones` values, and
meshStack rejects any tenant request that goes over the new limits.

## 📊 Shared Responsibility

| Responsibility | Platform Team | Application Team |
|---|:---:|:---:|
| Provide and operate the Kubernetes cluster | ✅ | ❌ |
| Create the replicator and metering service accounts in the cluster | ✅ | ❌ |
| Register the platform and its landing zones in meshStack | ✅ | ❌ |
| Choose the quota limits and the auto-approval thresholds | ✅ | ❌ |
| Rotate the cluster credentials the registration uses | ✅ | ❌ |
| Order a namespace on one of the landing zones | ❌ | ✅ |
| Deploy and operate workloads inside the namespace | ❌ | ✅ |
| Request a quota increase when a workload outgrows the landing zone | ❌ | ✅ |
| Monitor application health and logs | ❌ | ✅ |
