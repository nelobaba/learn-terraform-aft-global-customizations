# Custom Service Control Policies (SCPs)

Org-level SCPs, colocated with the AFT **global-customizations** baseline but
applied **against the management account** — not per member account.

## Why this lives here but is applied differently

AFT global-customizations (`../terraform/`) is auto-applied by the
`ct-aft-global-customizations` CodePipeline **inside each member account**
(its provider assumes `target_admin_role_arn` in the target account — see
`../terraform/aft-providers.jinja`).

SCPs are **organization-scoped** resources (`aws_organizations_policy`). They
must be created **once, against the management account**, not N times per
member. So this `scp/` directory:

- is **ignored by the AFT CodePipeline** (AFT only applies `terraform/` and
  `api_helpers/`), and
- is applied by its own workflow, `../.github/workflows/scp-deploy.yml`, which
  authenticates to the **management account** via GitHub OIDC.

This keeps SCPs in the same source-of-truth repo as your baseline (one place to
review guardrails) while respecting where they actually have to be created.

## What it creates

| SCP | Purpose | Default attachment |
|---|---|---|
| `custom-region-restriction` | Deny regional actions outside `allowed_regions`. Global services (IAM, Organizations, STS, Route 53, CloudFront, billing…) and automation roles are exempt. | Sandbox + Production OUs (`region_restriction_target_ou_ids`) |
| `custom-deny-log-tampering` | Deny disabling/deleting CloudTrail, Config, GuardDuty, Security Hub, and (optionally) modifying the central log buckets. CT/AFT roles exempt. | Org root (`log_tampering_target_ids`) → covers all member accounts |

> The **management account is always exempt** from SCPs, so attaching
> deny-log-tampering to the root is safe and does not risk locking out the
> factory. The `excluded_principal_arns` carve-out protects the Control Tower
> and AFT execution roles in **member** accounts so drift-remediation and
> account vending keep working.

## Prerequisites

1. **A role in the management account** for CI to assume, trusting GitHub OIDC,
   with permissions to manage SCPs:
   - `organizations:CreatePolicy`, `UpdatePolicy`, `DeletePolicy`,
     `AttachPolicy`, `DetachPolicy`, `List*`, `Describe*`.
   - Store its ARN as repo secret **`AWS_MGMT_SCP_ROLE_ARN`**.
2. **SCP policy type enabled** on the org root (Control Tower enables this):
   ```bash
   aws organizations list-roots \
     --query 'Roots[0].PolicyTypes[?Type==`SERVICE_CONTROL_POLICY`].Status'
   # Expect ["ENABLED"]
   ```
3. A remote state backend (fill in `versions.tf` `backend "s3"` or pass
   `-backend-config`).

## Configure

```bash
cd scp
cp terraform.tfvars.example terraform.tfvars
# Get the ids to fill in:
ROOT=$(aws organizations list-roots --query 'Roots[0].Id' --output text)
echo "root id: $ROOT"
aws organizations list-organizational-units-for-parent --parent-id "$ROOT" \
  --query 'OrganizationalUnits[].{Name:Name,Id:Id}' --output table
```
Edit `terraform.tfvars`: set `region_restriction_target_ou_ids` (Sandbox/Prod
OU ids), `log_tampering_target_ids` (the root id), and optionally
`central_log_bucket_arns`.

## Deploy

**Via CI (recommended):** merge to `main`; `scp-deploy.yml` plans on PRs and
applies on merge.

**Locally (management-account creds):**
```bash
cd scp
terraform init
terraform plan
terraform apply
```

## Verify / Test

```bash
# Policies exist
aws organizations list-policies --filter SERVICE_CONTROL_POLICY \
  --query "Policies[?starts_with(Name,'custom-')].{Name:Name,Id:Id}" --output table

# Where they're attached
aws organizations list-targets-for-policy \
  --policy-id "$(terraform -chdir=scp output -raw region_restriction_policy_id)" \
  --query 'Targets[].{Type:Type,Name:Name}' --output table
```

**Negative test (must be DENIED)** — assume a role in a Sandbox account and hit
a non-allowed region:
```bash
aws ec2 describe-instances --region eu-west-1   # expect AccessDenied
```
**Positive test (must SUCCEED)** — same call in an allowed region:
```bash
aws ec2 describe-instances --region us-east-2   # expect success
```
**Log-tampering test (must be DENIED)** — in a member account, try to silence
the trail:
```bash
aws cloudtrail stop-logging --name <trail>      # expect AccessDenied
```

## Safety notes (read before first apply)

- **Never remove the CT/AFT roles from `excluded_principal_arns`** — you will
  break drift-remediation and account vending.
- **Keep `us-east-2` and `us-east-1` in `allowed_regions`** — dropping the home
  or backend region will break Control Tower / AFT itself.
- Roll out to **Sandbox first**, verify, then Production. Attach broadly only
  after the negative/positive tests pass.
- Test edits with `terraform plan` on a PR; the workflow applies only on merge
  to `main`.
