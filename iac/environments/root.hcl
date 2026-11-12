# Root Terragrunt Configuration (root.hcl)
# Automatically configures the AWS provider to point to the local AWS Emulator

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region                      = "us-east-1"
  access_key                  = "mock_access_key"
  secret_key                  = "mock_secret_key"
  s3_use_path_style           = true
  insecure                    = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    s3         = "https://127.0.0.1:9297"
    sts        = "https://127.0.0.1:9297"
    cloudfront = "https://127.0.0.1:9297"
    iam        = "https://127.0.0.1:9297"
    kms        = "https://127.0.0.1:9297"
  }
}
EOF
}
