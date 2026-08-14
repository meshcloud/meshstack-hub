This building block gives you a STACKIT Kubernetes Engine (SKE) cluster with one autoscaling node
pool, a nightly maintenance window and a kubeconfig you can use right away. The platform team runs
the control plane, the node images and the Kubernetes version updates, and you run the workloads on
top of it.

## 🎯 When to use it

Use this building block when you:

- need a full Kubernetes cluster of your own rather than a namespace on a shared cluster
- want your workloads to stay on European infrastructure operated by STACKIT
- want STACKIT to handle control plane operation, node image updates and Kubernetes version updates
- plan to place the cluster inside a STACKIT Network Area so the control plane stays off the public internet

## 💡 Usage examples

**Example 1: A team platform for several environments**
Your team runs a set of services that need their own cluster-wide resources, such as custom resource
definitions and cluster-scoped operators. You order the cluster, take the kubeconfig from the outputs
and deploy your namespaces, operators and workloads into it.

**Example 2: A cluster behind a STACKIT Network Area**
Your workloads process data that must not be reachable from the public internet. You order the cluster
with a network id from your STACKIT network and set the control plane access scope to `SNA`, so the
Kubernetes API server answers only inside your network area.

## 🔑 Getting the kubeconfig

The building block exposes the kubeconfig as a sensitive output. Write it to a file and point
`kubectl` at it:

```bash
tofu output -raw kubeconfig > kubeconfig
kubectl --kubeconfig kubeconfig get nodes
```

The kubeconfig expires after 180 days by default. Terraform refreshes it on the next run once it
passes half of its lifetime, so keep applying the building block regularly.

## 📊 Shared Responsibility

| Responsibility | Platform Team | Application Team |
|---|:---:|:---:|
| Provision the SKE cluster and its node pool | ✅ | ❌ |
| Operate the Kubernetes control plane | ✅ | ❌ |
| Apply Kubernetes and machine image updates in the maintenance window | ✅ | ❌ |
| Provide the network and decide the control plane access scope | ✅ | ❌ |
| Rotate the kubeconfig before it expires | ✅ | ❌ |
| Deploy and operate workloads on the cluster | ❌ | ✅ |
| Set resource requests and limits for workloads | ❌ | ✅ |
| Manage namespaces and in-cluster RBAC | ❌ | ✅ |
| Store the kubeconfig somewhere safe | ❌ | ✅ |
| Monitor application health and logs | ❌ | ✅ |
