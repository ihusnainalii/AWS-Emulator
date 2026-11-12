# AWS Resources Reference

This document details:
1. **Provisioned Resources**: All resources created by our production-grade Terraform & Terragrunt modules.
2. **Supported AWS Emulator Services**: Complete catalog of AWS services and resources supported by the local AWS Emulator.

---

## 1. Provisioned Infrastructure Resources

The following resources are defined and provisioned across `modules/s3` and `modules/cloudfront`:

| Resource Type | Resource Identifier | Purpose & Security Configuration |
| :--- | :--- | :--- |
| `aws_kms_key` | `aws_kms_key.s3` | **Customer Managed Key (CMK)**: Dedicated KMS key for S3 server-side encryption with automated annual rotation enabled (`enable_key_rotation = true`). Policy allows root admin and CloudFront service principal. |
| `aws_kms_alias` | `aws_kms_alias.s3` | Human-readable alias for the KMS key (`alias/s3-<bucket_name>`). |
| `aws_s3_bucket` | `aws_s3_bucket.this` | S3 bucket resource with standardized environment tagging. |
| `aws_s3_bucket_versioning` | `aws_s3_bucket_versioning.this` | S3 bucket object versioning enabled (`status = "Enabled"`). |
| `aws_s3_bucket_server_side_encryption_configuration` | `aws_s3_bucket_server_side_encryption_configuration.this` | **SSE-KMS Encryption**: Enforces encryption at rest using the dedicated Customer Managed KMS Key with S3 Bucket Keys enabled (`bucket_key_enabled = true`). |
| `aws_s3_bucket_public_access_block` | `aws_s3_bucket_public_access_block.this` | **Total Internet Block**: Enables all 4 settings:<br>• `block_public_acls = true`<br>• `block_public_policy = true`<br>• `ignore_public_acls = true`<br>• `restrict_public_buckets = true` |
| `aws_cloudfront_origin_access_control` | `aws_cloudfront_origin_access_control.oac` | **Modern SigV4 OAC**: Origin Access Control for S3 origin (`signing_behavior = "always"`, `signing_protocol = "sigv4"`). |
| `aws_cloudfront_distribution` | `aws_cloudfront_distribution.cdn` | **CloudFront CDN**: Distribution pointing to S3 regional domain name protected by OAC. Allows HTTP methods `GET, HEAD, OPTIONS, PUT, POST, PATCH, DELETE`. Redirects HTTP to HTTPS. |
| `aws_s3_bucket_policy` | `aws_s3_bucket_policy.cloudfront_access` | **Granular Access Policy**:<br>1. **Enforce TLS**: Denies all requests without SSL (`aws:SecureTransport = false`).<br>2. **CloudFront OAC Access**: Restricts object operations exclusively to the CloudFront distribution ARN for `s3:GetObject`, `s3:PutObject`, and `s3:DeleteObject`. |

---

## 2. Supported AWS Emulator Services Catalog

The official AWS Emulator supports **347 distinct AWS services** modeled directly from the official AWS API definitions. Because resources run locally in container memory, they spin up instantly with zero cloud charges.

### Storage & Content Delivery
* **Amazon S3**: Buckets, objects, versioning, multipart uploads, lifecycle rules, bucket policies, CORS, presigned URLs.
* **Amazon CloudFront**: Distributions, origin access controls (OAC), cache policies, origin request policies.
* **Amazon EFS**: Elastic file systems, mount targets, access points.
* **AWS S3 Control & S3 Tables**: Batch operations, access grants, table buckets.

### Databases, Caching & Analytics
* **Amazon DynamoDB**: Tables, global secondary indexes (GSI), local secondary indexes (LSI), item CRUD, query, scan, streams, PartiQL.
* **Amazon RDS / Aurora**: DB instances, database clusters, subnet groups, parameter groups, snapshots.
* **Amazon OpenSearch / OpenSearch Serverless**: Domains, collections, indexes, access policies.
* **Amazon Redshift / Redshift Serverless**: Clusters, namespaces, workgroups.
* **Amazon MemoryDB & ElastiCache**: Redis/Memcached clusters, parameter groups.
* **Amazon Athena & AWS Glue**: Data catalogs, databases, tables, query executions.

### Compute & Containers
* **AWS Lambda**: Functions, layers, versions, aliases, function URLs, event source mappings.
* **Amazon ECS**: Clusters, task definitions, services, tasks, capacity providers.
* **Amazon ECR**: Container repositories, image tags, lifecycle policies.
* **Amazon EC2**: Virtual machines, VPCs, subnets, route tables, internet gateways, NAT gateways, security groups, elastic IPs.
* **AWS Auto Scaling**: Scaling plans, scaling policies, target groups.
* **AWS Batch**: Compute environments, job queues, job definitions, jobs.

### Messaging, Events & Orchestration
* **Amazon SQS**: Standard and FIFO queues, dead-letter queues (DLQ), send/receive/delete messages.
* **Amazon SNS**: Topics, subscriptions (SQS, Lambda, HTTP, email), publishing.
* **Amazon EventBridge**: Custom event buses, rules, event patterns, API destinations.
* **Amazon EventBridge Scheduler**: Recurring and one-time cron schedule targets.
* **Amazon EventBridge Pipes**: Event filtering, enrichment, source-to-target piping.
* **AWS Step Functions**: State machines, task executions, distributed maps, sagas.
* **Amazon Kinesis & Firehose**: Data streams, shards, delivery streams.

### API & Networking
* **Amazon API Gateway (v1 & v2)**: REST APIs, HTTP APIs, WebSocket APIs, resources, methods, integrations, stages, authorizers.
* **AWS AppSync**: GraphQL APIs, schema definitions, resolvers, data sources.
* **Amazon Route 53**: Public and private hosted zones, DNS record sets, health checks.
* **Elastic Load Balancing (ALB, NLB, ELBv2)**: Load balancers, listeners, listener rules, target groups.
* **Amazon VPC Lattice**: Service networks, services, listeners, targets.

### Security, Identity & Cryptography
* **AWS KMS**: Customer Managed Keys (CMK), key aliases, key policies, grants, encrypt/decrypt operations.
* **AWS Secrets Manager**: Secrets, secret versions, automated rotation configurations.
* **AWS Systems Manager (SSM) Parameter Store**: Standard, SecureString, and StringList parameters.
* **AWS IAM**: Roles, policies, users, groups, instance profiles.
* **AWS STS**: AssumeRole, GetCallerIdentity, temporary session credentials.
* **Amazon Cognito**: User Pools, App Clients, Identity Pools.
* **AWS Certificate Manager (ACM)**: SSL/TLS certificates.
* **AWS WAFv2**: Web ACLs, IP sets, rule groups.

### Observability & Infrastructure as Code
* **Amazon CloudWatch**: Metrics, alarms, composite alarms, dashboards.
* **Amazon CloudWatch Logs**: Log groups, log streams, metric filters, retention policies.
* **AWS X-Ray**: Trace collection, segments, sampling rules.
* **AWS CloudFormation**: Stacks, stack sets, change sets.

### Generative AI & Machine Learning
* **Amazon Bedrock**: Bedrock models, Bedrock Agent, agent runtimes, action groups.
* **Amazon SageMaker**: Models, endpoints, endpoint configurations, training jobs.
* **AI Services**: Textract, Rekognition, Polly, Translate, Transcribe.
