# AWS Route53 DNS Record

## Description
This building block creates standard DNS records for mapping domain names to IP addresses or other values.

## When to Use
- Create DNS records (A, AAAA, CNAME, TXT, MX, SRV, etc.)
- Point subdomain names to IP addresses or other domains
- Configure email routing, domain verification, or service discovery

## Shared Responsibility

| Responsibility | Platform Team | Application Team |
|----------------|---------------|------------------|
| Managing Route53 hosted zones | ✅ | ❌ |
| Provisioning DNS records | ❌ | ✅ |
| Managing record values and TTL | ❌ | ✅ |

## Key Recommendations
- Choose appropriate TTL: Lower (e.g., 300s) for frequent changes, higher (e.g., 3600s) for stable records
- Use descriptive DNS names that clearly indicate the service
- Test DNS changes in development environments first
- Remember: DNS changes take time to propagate (up to TTL duration)
