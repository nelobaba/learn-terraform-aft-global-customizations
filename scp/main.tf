data "aws_organizations_organization" "this" {}

locals {
  # Region-agnostic / global services that must stay usable no matter which
  # region the caller hits. If these were denied, IAM, Organizations, Route 53,
  # CloudFront, STS, billing, etc. would break org-wide.
  global_services = [
    "iam:*",
    "organizations:*",
    "sts:*",
    "route53:*",
    "route53domains:*",
    "cloudfront:*",
    "waf:*",
    "wafv2:*",
    "waf-regional:*",
    "shield:*",
    "globalaccelerator:*",
    "support:*",
    "trustedadvisor:*",
    "health:*",
    "budgets:*",
    "ce:*",
    "cur:*",
    "tag:*",
    "artifact:*",
    "account:*",
    "notifications:*",
    "kms:*", # kms is regional, but denying it breaks cross-region key use during vending; scope elsewhere if needed
  ]

  # ---- SCP 1: region restriction -----------------------------------------
  region_restriction_doc = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyOutsideAllowedRegions"
        Effect    = "Deny"
        NotAction = local.global_services
        Resource  = "*"
        Condition = {
          StringNotEquals = { "aws:RequestedRegion" = var.allowed_regions }
          ArnNotLike      = { "aws:PrincipalArn" = var.excluded_principal_arns }
        }
      }
    ]
  })

  # ---- SCP 2: deny log / security-service tampering -----------------------
  # Statement A always applies: no member principal (except the carved-out
  # automation roles) may disable the detective controls.
  log_tampering_statements = concat(
    [
      {
        Sid    = "DenyDisableSecurityServices"
        Effect = "Deny"
        Action = [
          # CloudTrail — the audit trail must not be silenced or deleted
          "cloudtrail:StopLogging",
          "cloudtrail:DeleteTrail",
          "cloudtrail:UpdateTrail",
          "cloudtrail:PutEventSelectors",
          # AWS Config — recorders/channels must keep running
          "config:StopConfigurationRecorder",
          "config:DeleteConfigurationRecorder",
          "config:DeleteDeliveryChannel",
          "config:DeleteConfigRule",
          "config:DeleteOrganizationConfigRule",
          # GuardDuty — threat detection must not be disabled/detached
          "guardduty:DeleteDetector",
          "guardduty:UpdateDetector",
          "guardduty:DisassociateFromMasterAccount",
          "guardduty:DisassociateFromAdministratorAccount",
          "guardduty:DeleteMembers",
          "guardduty:DisassociateMembers",
          "guardduty:StopMonitoringMembers",
          # Security Hub — findings aggregation must stay on
          "securityhub:DisableSecurityHub",
          "securityhub:DisassociateFromMasterAccount",
          "securityhub:DisassociateFromAdministratorAccount",
          "securityhub:DeleteMembers",
          "securityhub:DisassociateMembers",
          "securityhub:BatchDisableStandards",
        ]
        Resource = "*"
        Condition = {
          ArnNotLike = { "aws:PrincipalArn" = var.excluded_principal_arns }
        }
      }
    ],
    # Statement B only renders when central log bucket ARNs are supplied, so we
    # never emit an SCP with an empty Resource (which AWS rejects).
    length(var.central_log_bucket_arns) == 0 ? [] : [
      {
        Sid    = "ProtectCentralLogBuckets"
        Effect = "Deny"
        Action = [
          "s3:DeleteBucket",
          "s3:DeleteBucketPolicy",
          "s3:PutBucketPolicy",
          "s3:PutBucketAcl",
          "s3:PutEncryptionConfiguration",
          "s3:DeleteObject",
          "s3:DeleteObjectVersion",
          "s3:PutLifecycleConfiguration",
          "s3:PutBucketVersioning",
          "s3:PutBucketObjectLockConfiguration",
        ]
        Resource = var.central_log_bucket_arns
        Condition = {
          ArnNotLike = { "aws:PrincipalArn" = var.excluded_principal_arns }
        }
      }
    ]
  )

  log_tampering_doc = jsonencode({
    Version   = "2012-10-17"
    Statement = local.log_tampering_statements
  })
}

# --------------------------------------------------------------------------
# SCP 1: Region restriction
# --------------------------------------------------------------------------
resource "aws_organizations_policy" "region_restriction" {
  name        = "custom-region-restriction"
  description = "Deny regional actions outside ${join(", ", var.allowed_regions)}; global services and automation roles exempt."
  type        = "SERVICE_CONTROL_POLICY"
  content     = local.region_restriction_doc
}

resource "aws_organizations_policy_attachment" "region_restriction" {
  for_each  = toset(var.region_restriction_target_ou_ids)
  policy_id = aws_organizations_policy.region_restriction.id
  target_id = each.value
}

# --------------------------------------------------------------------------
# SCP 2: Deny log / security-service tampering
# --------------------------------------------------------------------------
resource "aws_organizations_policy" "deny_log_tampering" {
  name        = "custom-deny-log-tampering"
  description = "Deny disabling CloudTrail/Config/GuardDuty/SecurityHub and tampering with central log buckets; CT/AFT roles exempt."
  type        = "SERVICE_CONTROL_POLICY"
  content     = local.log_tampering_doc
}

resource "aws_organizations_policy_attachment" "deny_log_tampering" {
  for_each  = toset(var.log_tampering_target_ids)
  policy_id = aws_organizations_policy.deny_log_tampering.id
  target_id = each.value
}
