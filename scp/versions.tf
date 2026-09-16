terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }

  # Remote state in a dedicated bucket + lock table in the management account
  # (368289941955). Created via one-off CLI bootstrap; see scp/README.md.
  backend "s3" {
    bucket         = "tf-state-org-scp-368289941955-us-east-2"
    key            = "org/scp/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "tf-state-lock-org-scp"
    encrypt        = true
  }
}
