# Global customizations — applied to EVERY AFT-vended account by the
# `aft-global-customizations-terraform` CodeBuild project.
#
# AFT renders the provider + backend from aft-providers.jinja / backend.jinja at
# apply time and injects the per-account assume-role, so no providers.tf/backend
# is needed here. Keep this baseline cheap, safe, and easy to verify from the
# CLI (see Lab 7 §7 / §15).
#
# NOTE: org-scoped SCPs are NOT applied here — they live in the sibling scp/ dir
# and are applied to the MANAGEMENT account by the `org-custom-scp` GitHub
# Actions workflow (.github/workflows/scp-deploy.yml), not this CodeBuild.

# 1) Default EBS encryption on.
#    Verify: aws ec2 get-ebs-encryption-by-default --query 'EbsEncryptionByDefault'
resource "aws_ebs_encryption_by_default" "this" {
  enabled = true
}

# 2) Strong IAM account password policy.
#    Verify: aws iam get-account-password-policy
resource "aws_iam_account_password_policy" "this" {
  minimum_password_length        = 14
  require_symbols                = true
  require_numbers                = true
  require_uppercase_characters   = true
  require_lowercase_characters   = true
  allow_users_to_change_password = true
  max_password_age               = 90
  password_reuse_prevention      = 24
}

# 3) Marker parameter proving the global run touched this account.
#    Verify: aws ssm get-parameter --name /aft/global-customizations/applied
resource "aws_ssm_parameter" "global_marker" {
  name  = "/aft/global-customizations/applied"
  type  = "String"
  value = timestamp()

  lifecycle {
    # timestamp() changes every plan; don't churn the value on every run.
    ignore_changes = [value]
  }
}
