output "bucket_id" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.this.arn
}

output "bucket_domain_name" {
  description = "Bucket domain name"
  value       = aws_s3_bucket.this.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "Regional domain name of the bucket (for CloudFront origin)"
  value       = aws_s3_bucket.this.bucket_regional_domain_name
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for S3 encryption"
  value       = try(aws_kms_key.s3[0].arn, null)
}

output "kms_key_id" {
  description = "ID of the KMS key used for S3 encryption"
  value       = try(aws_kms_key.s3[0].key_id, null)
}
