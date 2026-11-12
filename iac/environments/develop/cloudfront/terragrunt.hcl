include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/cloudfront"
}

dependency "s3" {
  config_path = "../s3"

  mock_outputs = {
    bucket_id                   = "mock-bucket"
    bucket_arn                  = "arn:aws:s3:::mock-bucket"
    bucket_regional_domain_name = "mock-bucket.s3.us-east-1.amazonaws.com"
  }
}

inputs = {
  s3_bucket_id          = dependency.s3.outputs.bucket_id
  s3_bucket_arn         = dependency.s3.outputs.bucket_arn
  s3_bucket_domain_name = dependency.s3.outputs.bucket_regional_domain_name
  environment           = "develop"
  attach_s3_policy      = true
  allow_public_read     = true

  tags = {
    Project     = "AWS-Emulator"
    Environment = "develop"
    ManagedBy   = "Terragrunt"
  }
}
