output "region_restriction_policy_id" {
  description = "SCP id for the region-restriction policy."
  value       = aws_organizations_policy.region_restriction.id
}

output "region_restriction_attached_to" {
  description = "OU ids the region-restriction SCP is attached to."
  value       = keys(aws_organizations_policy_attachment.region_restriction)
}

output "deny_log_tampering_policy_id" {
  description = "SCP id for the deny-log-tampering policy."
  value       = aws_organizations_policy.deny_log_tampering.id
}

output "deny_log_tampering_attached_to" {
  description = "Target ids (root/OUs) the deny-log-tampering SCP is attached to."
  value       = keys(aws_organizations_policy_attachment.deny_log_tampering)
}

output "organization_root_id" {
  description = "Convenience: the org root id (attach deny-log-tampering here to cover all member accounts)."
  value       = data.aws_organizations_organization.this.roots[0].id
}
