# SCPs are ORG-level resources and must be created against the ORGANIZATION
# MANAGEMENT account (or a delegated policy administrator). This is the key
# difference from AFT global-customizations, whose provider assumes a role in
# each *member* account. Here we target the management account.
#
# Two supported credential models (pick one):
#   1. Run CI/apply directly with management-account credentials (leave
#      management_account_role_arn = null). Simplest with GitHub OIDC → a role
#      in the management account.
#   2. Run from elsewhere and assume a role into the management account by
#      setting management_account_role_arn.

provider "aws" {
  region = var.home_region

  dynamic "assume_role" {
    for_each = var.management_account_role_arn == null ? [] : [1]
    content {
      role_arn     = var.management_account_role_arn
      session_name = "org-custom-scp"
    }
  }

  default_tags {
    tags = {
      managed_by = "terraform"
      component  = "org-custom-scp"
      repo       = "learn-terraform-aft-global-customizations/scp"
    }
  }
}
