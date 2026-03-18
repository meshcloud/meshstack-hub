# STACKIT Storage Bucket

This building block provisions an S3-compatible Object Storage bucket on STACKIT with access credentials.
Application teams receive a dedicated bucket with S3-compatible access keys for storing objects.

## 🚀 Usage Motivation

This building block is designed for application teams that need to:
- Store and retrieve objects (files, backups, logs, artifacts) via S3-compatible APIs
- Integrate with applications and tools that support the S3 protocol
- Get self-service access to managed object storage without platform team involvement per bucket

## 💡 Usage Examples

- A development team stores application artifacts and build outputs in a dedicated bucket.
- A data team uses a bucket as a data lake landing zone for incoming data files.
- An operations team stores log archives and backup snapshots for long-term retention.

## 🔄 Shared Responsibility

| Responsibility | Platform Team | Application Team |
|---------------|--------------|-----------------|
| Provisioning Object Storage backplane (admin credentials, service account) | ✅ | ❌ |
| Creating and deleting buckets | ✅ (via building block) | ❌ |
| Enforcing per-bucket access isolation via bucket policies | ✅ (via building block) | ❌ |
| Managing bucket contents | ❌ | ✅ |
| Securing access keys and secret keys | ❌ | ✅ |
| Monitoring storage usage and costs | ✅ | ✅ |
| Configuring application access to bucket | ❌ | ✅ |

## 💡 Recommendations

- **Use descriptive bucket names**: Include the team or application name for easy identification.
- **Rotate credentials regularly**: Treat access keys like passwords — rotate them periodically.
- **Do not commit secret keys**: Store the secret access key in a secrets manager, never in source control.
- **Use virtual-hosted-style URLs**: Prefer virtual-hosted-style URLs for better compatibility with S3 SDKs.
