variable "bucket_name" {
  description = "The name of the S3 bucket"
  type        = string
}

variable "environment" {
  description = "Deployment environment name (e.g., develop, staging, prod)"
  type        = string
  default     = "develop"
}

variable "enable_versioning" {
  description = "Whether to enable S3 bucket versioning"
  type        = bool
  default     = true
}

variable "block_public_access" {
  description = "Whether to enable S3 public access block"
  type        = bool
  default     = true
}

variable "allow_public_read" {
  description = "Whether to allow public read access (s3:GetObject) for direct browser viewing"
  type        = bool
  default     = true
}

variable "enable_kms_encryption" {
  description = "Whether to create a dedicated KMS CMK and enable SSE-KMS on the bucket"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to attach to resources"
  type        = map(string)
  default     = {}
}
