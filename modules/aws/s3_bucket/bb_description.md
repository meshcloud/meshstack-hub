# AWS S3 Bucket

## Description
This building block provides an AWS S3 bucket for object storage. It enables application teams to store and retrieve data securely with configurable access controls, lifecycle policies, and encryption.

## Usage Motivation
This building block is for application teams that need scalable and durable object storage for their applications. AWS S3 is suitable for a variety of use cases, including:
- Storing application logs, backups, and media files.
- Hosting static websites or distributing content.
- Archiving data with lifecycle policies to optimize storage costs.

## Usage Examples
- A development team stores logs from their microservices in an S3 bucket with automated retention policies.
- A data analytics team uploads large datasets to an S3 bucket for processing using AWS Glue and Athena.

## Shared Responsibility

| Responsibility          | Platform Team | Application Team |
|------------------------|--------------|----------------|
| Creating and maintaining automation for provisioning S3 buckets | ✅ | ❌ |
| Enforcing security policies (e.g., encryption, access control) | ✅ | ❌ |
| Provisioning an S3 bucket | ✅ | ❌ |
| Managing access policies and permissions | ❌ | ✅ |
| Uploading, modifying, and deleting data | ❌ | ✅ |
| Configuring lifecycle policies for data retention | ❌ | ✅ |

## Recommendations for Secure and Cost-Effective S3 Usage
- **Enable encryption**: Use server-side encryption (SSE) to protect stored data.
- **Set access policies**: Follow the principle of least privilege with IAM policies and bucket policies.
- **Use lifecycle rules**: Automatically move data to lower-cost storage classes (e.g., S3 Glacier) based on access patterns.
- **Enable versioning**: Protect against accidental deletions by keeping previous versions of objects.
- **Monitor and optimize costs**: Use AWS Cost Explorer and S3 Storage Lens for cost insights.
