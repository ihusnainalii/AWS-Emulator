include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/s3"
}

inputs = {
  bucket_name           = "develop-secure-assets"
  environment           = "develop"
  enable_versioning     = true
  block_public_access   = true
  allow_public_read     = true
  enable_kms_encryption = true

  tags = {
    Project     = "AWS-Emulator"
    Environment = "develop"
    ManagedBy   = "Terragrunt"
  }
}
