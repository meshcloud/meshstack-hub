Your services in this cluster get a public HTTPS URL with a certificate that browsers trust. The platform team runs an ingress controller and cert-manager for you, so all you add to your service is an Ingress object with a hostname.

## 🎯 When to use it

Use this building block when you:
- want to reach a service in the cluster from outside, over a real domain name instead of a port forward
- need TLS that browsers, mobile apps and API clients accept without a warning
- do not want to buy, renew or store certificates yourself

## 💡 Usage examples

**Example 1: Publish a web frontend**
You deploy a frontend Service in your namespace and add an Ingress for `shop.example.com` with the platform's ingress class. The controller starts routing traffic to your Service and the hostname answers over HTTPS right away.

**Example 2: Expose an API for a partner**
Your team needs a stable HTTPS endpoint for a partner integration. You create an Ingress for `api.example.com`, hand the URL to the partner, and the certificate keeps renewing itself as long as the Ingress exists.

## 🔧 How to use it

Add an Ingress to your namespace and set the ingress class the platform team gave you:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: shop
spec:
  ingressClassName: haproxy
  rules:
    - host: shop.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: shop
                port:
                  number: 8080
```

When the platform team runs a wildcard certificate for the cluster domain, that is all you need — the controller already serves a valid certificate for every hostname in the zone.

For a hostname outside that zone, ask cert-manager for its own certificate. Add the ClusterIssuer annotation and a `tls` section:

```yaml
metadata:
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
    - hosts:
        - shop.example.com
      secretName: shop-tls
```

The hostname has to resolve to the ingress load balancer before Let's Encrypt can validate it, so create the DNS record first.

## ⚙️ What the platform team installs

The platform team runs this module against your cluster. The module brings no cluster credentials
of its own: the caller configures the `kubernetes` and the `helm` provider and hands both to the
module.

```hcl
module "ingress" {
  source = "github.com/meshcloud/meshstack-hub//modules/kubernetes/ingress/buildingblock?ref=main"

  providers = {
    kubernetes = kubernetes
    helm       = helm
  }

  acme_email = "platform@example.com"
}
```

**The resource requests and limits of the ingress controller and of cert-manager default to
demonstration sizes.** HAProxy runs as a single replica with 100m CPU requested, which is enough
to show a service answering over HTTPS and not enough to carry production traffic. Ask your
platform team to raise `haproxy_replica_count` and the `*_resources` variables before you put a
real workload behind this ingress.

## 📊 Shared Responsibility

| Responsibility | Platform Team | Application Team |
|---|:---:|:---:|
| Run the ingress controller and its load balancer | ✅ | ❌ |
| Run cert-manager and the Let's Encrypt ClusterIssuer | ✅ | ❌ |
| Renew the wildcard certificate for the cluster domain | ✅ | ❌ |
| Create DNS records for the cluster domain | ✅ | ❌ |
| Create the Ingress object and pick the hostname | ❌ | ✅ |
| Keep the backend Service healthy and reachable | ❌ | ✅ |
| Create DNS records for hostnames outside the cluster domain | ❌ | ✅ |
| Authentication and authorization inside the application | ❌ | ✅ |
