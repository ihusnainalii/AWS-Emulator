variable "s3_bucket_id" {
  description = "The ID of the S3 bucket to serve"
  type        = string
}

variable "s3_bucket_arn" {
  description = "The ARN of the S3 bucket"
  type        = string
}

variable "s3_bucket_domain_name" {
  description = "The domain name of the S3 bucket (use regional domain name for OAC)"
  type        = string
}

variable "origin_id" {
  description = "Unique identifier for the CloudFront origin"
  type        = string
  default     = "s3-origin"
}

variable "default_root_object" {
  description = "The object that CloudFront returns when an end user requests the root URL"
  type        = string
  default     = null
}

variable "environment" {
  description = "Deployment environment name (e.g., develop, staging, prod)"
  type        = string
  default     = "develop"
}

variable "attach_s3_policy" {
  description = "Whether to attach/update the S3 bucket policy to allow CloudFront OAC read access and enforce SSL"
  type        = bool
  default     = true
}

variable "allow_public_read" {
  description = "Whether to allow public read access (s3:GetObject) on the bucket for direct browser access"
  type        = bool
  default     = true
}

variable "enforce_tls" {
  description = "Whether to enforce TLS via bucket policy condition (set false on local emulators that lack SecureTransport condition evaluation)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to attach to resources"
  type        = map(string)
  default     = {}
}
