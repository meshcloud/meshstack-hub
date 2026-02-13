# AWS Route53 DNS Alias Record

## Description
This building block creates Route53 alias records, which are AWS-specific DNS records that can only route traffic to AWS resources (load balancers, CloudFront distributions, S3 websites, etc.).

## When to Use
- Point custom domains to AWS load balancers (ALB/NLB)
- Route traffic to CloudFront distributions
- Create apex/root domain records (e.g., example.com)

## Shared Responsibility

| Responsibility | Platform Team | Application Team |
|----------------|---------------|------------------|
| Managing Route53 hosted zones | ✅ | ❌ |
| Provisioning DNS alias records | ❌ | ✅ |
| Managing record names and target resources | ❌ | ✅ |

## Key Recommendations
- Use descriptive DNS names (e.g., `api.example.com`, `www.example.com`)
- Enable health checks for automatic failover when appropriate
- Coordinate with your platform team before modifying production DNS records
