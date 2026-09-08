terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }

  # Remote state lives in the AFT/management backend. Fill these in (or pass
  # via `-backend-config`) so SCP state is versioned and locked like everything
  # else. Left as a partial config on purpose — see scp/README.md.
  backend "s3" {
    # bucket         = "<tf-state-bucket-in-mgmt-or-aft>"
    # key            = "org/scp/terraform.tfstate"
    # region         = "us-east-2"
    # dynamodb_table = "<tf-lock-table>"
    # encrypt        = true
  }
}
