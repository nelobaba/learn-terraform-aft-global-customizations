variable "home_region" {
  description = "Control Tower home region (used for the org API endpoint)."
  type        = string
  default     = "us-east-2"
}

variable "management_account_role_arn" {
  description = <<-EOT
    Optional role ARN to assume in the ORG MANAGEMENT account to manage SCPs.
    Leave null when running with management-account credentials directly
    (e.g. GitHub OIDC into a role in the management account).
  EOT
  type        = string
  default     = null
}

variable "allowed_regions" {
  description = <<-EOT
    Regions where regional actions are permitted. Everything else is denied by
    the region-restriction SCP. Keep the CT home region and the TF backend
    secondary region in here or you will break the factory.
  EOT
  type        = list(string)
  default     = ["us-east-2", "us-east-1"]
}

variable "region_restriction_target_ou_ids" {
  description = <<-EOT
    OU IDs to attach the region-restriction SCP to (e.g. Sandbox, Production,
    Infrastructure). Get them with:
      ROOT=$(aws organizations list-roots --query 'Roots[0].Id' --output text)
      aws organizations list-organizational-units-for-parent --parent-id "$ROOT"
  EOT
  type        = list(string)
}

variable "log_tampering_target_ids" {
  description = <<-EOT
    Where to attach the deny-log-tampering SCP. Attaching the ROOT id covers
    every member account (the management account itself is always exempt from
    SCPs). You can instead pass a list of OU ids if you prefer OU-scoped.
  EOT
  type        = list(string)
}

variable "excluded_principal_arns" {
  description = <<-EOT
    Principal ARN patterns that must NOT be blocked by either SCP — the
    automation identities that legitimately operate the platform. Control Tower
    and AFT roles MUST be here or drift-remediation / account vending breaks.
    Wildcards are matched with aws:PrincipalArn (ArnNotLike).
  EOT
  type        = list(string)
  default = [
    "arn:aws:iam::*:role/AWSControlTowerExecution",
    "arn:aws:iam::*:role/aws-controltower-*",
    "arn:aws:iam::*:role/AWSAFTExecution",
    "arn:aws:iam::*:role/AWSAFTService",
    "arn:aws:iam::*:role/stacksets-exec-*",
  ]
}

variable "central_log_bucket_arns" {
  description = <<-EOT
    ARNs of the centralized log buckets in the Log Archive account to protect
    from deletion/modification. Include both the bucket and /* object ARNs.
    Find them from the Log Archive account:
      aws s3 ls | grep -Ei 'aws-controltower|logs|config'
  EOT
  type        = list(string)
  default     = []
}
