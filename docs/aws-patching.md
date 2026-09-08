# AWS Patch Manager — End-to-End Demo

Run a full cloud-patch-automation demo on AWS, from zero to destroy, and
capture the evidence for the README table. Budget **~1 hour** (mostly waiting
on the SSM agent and the patch scan).

This needs a **real AWS account** — LocalStack or other emulators can apply
the Terraform, but they cannot run actual patch scans or Windows Update.

## 0. Prerequisites

- Terraform >= 1.15
- AWS CLI with admin-level credentials (the stack creates EC2, SSM, S3,
  SNS, EventBridge, IAM):
  ```bash
  aws sts get-caller-identity
  ```
- **CLI region matches the stack** (`us-east-1`). EC2 and SSM are regional —
  a different default region makes every `describe-*` below return empty or
  `NotFound`:
  ```bash
  aws configure set region us-east-1
  aws configure get region
  ```
- A mailbox you can open **right now** for the SNS alert (confirm the
  subscription link).
- No state bucket needed: state is **local** by default
  (`aws/terraform.tfstate`). The S3 backend is only for CI.

## 1. Configure, plan, apply the patch infrastructure

```bash
cd aws
cp terraform.tfvars.example terraform.tfvars
# set alert_email to your mailbox

terraform init
terraform plan   # ~24 to add: baselines, patch groups, maintenance windows,
                 # S3 + SNS + EventBridge, IAM. No EC2 instances yet.
terraform apply
terraform output  # note patch_groups, maintenance_windows, compliance_bucket
```

## 2. Verify the SSM components

```bash
# Baselines - both custom baselines must appear
aws ssm describe-patch-baselines \
  --query 'BaselineIdentities[].{Name:BaselineName,Id:BaselineId}' --output table

# Patch groups - each OS version group maps to a baseline
aws ssm describe-patch-groups --output table

# Maintenance windows - weekly-patch-scan + monthly-patch-install
aws ssm describe-maintenance-windows \
  --query 'WindowIdentities[].{Name:Name,Id:WindowId,Schedule:Schedule}' --output table

# Window targets + tasks (paste the window ids above)
aws ssm describe-maintenance-window-targets --window-id <window-id> --output table
aws ssm describe-maintenance-window-tasks  --window-id <window-id> --output table
```

Console cross-check: **Systems Manager → Patch Manager → Baselines** and
**→ Maintenance windows**.

## 3. Start the demo fleet + confirm the email

1. Set `enable_demo_vms = true` in `terraform.tfvars`, then:
   ```bash
   terraform apply
   terraform output demo_instance_ids
   ```
   The VMs launch on **Spot** (`enable_spot = true`). If apply fails on spot
   capacity, retry once, then set `enable_spot = false` for on-demand.
2. Open the inbox for `alert_email` and click **Confirm subscription**.
   Verify:
   ```bash
   aws sns list-subscriptions-by-topic \
     --topic-arn "$(terraform output -raw compliance_alert_topic)" \
     --query 'Subscriptions[].{Endpoint:Endpoint,Status:SubscriptionArn}' --output table
   ```
   `Status` must be a full ARN (`Confirmed`), not `PendingConfirmation`.
3. Confirm the version tags:
   ```bash
   aws ec2 describe-instances \
     --instance-ids "$(terraform output -json demo_instance_ids | jq -r '.linux')" \
     --query 'Reservations[].Instances[].Tags' --output table
   ```
   Expect `os=linux`, `os_version=2023`, `Patch Group=demo-linux-2023` (and
   the windows equivalents).

## 4. Wait for the SSM agent to check in

Both AMIs ship the agent preinstalled, but registration takes **5–15 min**.
Poll until both instances show `PingStatus: Online`:

```bash
aws ssm describe-instance-information \
  --query 'InstanceInformationList[].{Instance:InstanceId,Ping:PingStatus,Agent:AgentVersion}' \
  --output table
```

## 5. Run a scan on demand (don't wait for Saturday)

The maintenance window cron runs on **UTC**, which is why the demo triggers
the scan manually:

```bash
aws ssm send-command \
  --document-name "AWS-RunPatchBaseline" \
  --targets "Key=tag:Patch Group,Values=demo-linux-2023,demo-windows-2025" \
  --parameters '{"Operation":["Scan"]}' \
  --timeout-seconds 600
# note the CommandId, then watch it (2-10 min; Windows first scan is slower)
aws ssm list-command-invocations --command-id <command-id> --details --output table
aws ssm get-command-invocation --command-id <command-id> --instance-id <instance-id> \
  --query '{Status:Status,Output:StandardOutputContent}'
```

Pass = `Status: Success` on both instances.

## 6. Verify compliance, the S3 export, and the email alert

```bash
# CLI: compliance summaries
aws ssm list-compliance-summaries --output table
aws ssm list-resource-compliance-summaries \
  --filters Key=ComplianceType,Values=Patch --output table

# Optional: S3 resource data sync output (appears after the scan;
# first sync can lag ~15 min)
aws s3 ls "s3://$(terraform output -raw compliance_bucket)/patch-compliance/" --recursive
```

The EventBridge rule fires on compliance state *change* — the first scan
usually triggers it. Check the inbox for the alert.

**Screenshot checklist (paste into the README evidence table):**

- [ ] **Patch Manager → Compliance**: both instances, one patch group per
      version (`demo-windows-2025`, `demo-linux-2023`), baseline per OS,
      missing-patch counts.
- [ ] **Patch Manager → Baselines**: the two custom baselines with the
      3-day approval delay visible.
- [ ] **Maintenance windows**: weekly scan + monthly install schedules.
- [ ] **S3**: sync JSON under `patch-compliance/` in the compliance bucket.
- [ ] **Inbox**: the SNS email alert on compliance state change.

## 7. Install demo (optional, proves the loop)

```bash
aws ssm send-command \
  --document-name "AWS-RunPatchBaseline" \
  --targets "Key=tag:Patch Group,Values=demo-linux-2023,demo-windows-2025" \
  --parameters '{"Operation":["Install"],"RebootOption":["RebootIfNeeded"]}' \
  --timeout-seconds 1800
```

Expect Windows to reboot and take 10–30 min (dozens of updates on a fresh
AMI). Re-run the step-6 checks — missing counts drop (typically to 0) and
the alert fires again.

## 8. Tear down

```bash
# Option A: keep the ~$0 infra, remove only the VMs
terraform apply -var='enable_demo_vms=false'

# Option B: destroy everything (force_destroy empties the versioned
# compliance bucket automatically)
terraform destroy
```

Verify nothing is left running:

```bash
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running,pending" \
  --query 'Reservations[].Instances[].InstanceId' --output text
# expect: empty output
```

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `Backend initialization required` on plan | Stale `.terraform` from an older init. `terraform init` (or `rm -rf .terraform && terraform init`) |
| `ec2:DescribeImages` denied (SCP) on plan | Infra-only plans don't need it (AMI lookups are gated on `enable_demo_vms`); enabling the VMs does — relax the org SCP or use an unrestricted account |
| `InvalidInstanceID.NotFound` on a tag check | CLI is in the wrong region or account. Instance lives in `us-east-1`; `aws configure set region us-east-1` and check `aws sts get-caller-identity` |
| SSM `describe-*` returns empty | Same cause: regional API, wrong default region |
| Instance never shows `Online` in SSM | Wait up to 15 min; instance must have the `patch-demo-ssm` profile and outbound access to `ssm.<region>.amazonaws.com` |
| Spot capacity error on apply | Retry once, then `enable_spot = false` for on-demand |
| Demo VM disappeared mid-test | Spot reclaim (rare for these types) — `terraform apply` recreates it, re-run the scan |
| Compliance empty after a successful scan | Give Patch Manager ~5 min to process |
| Fresh AMIs show 0 missing patches | AMI is newer than the 3-day approval window — run the install (step 7), then rescan |
| No email alert | SNS subscription must be Confirmed; the rule fires only on state *change* — the install step guarantees one |
| `terraform destroy` fails on the bucket | Bucket versioned + non-empty. The bucket now has `force_destroy = true`, so re-running destroy purges objects and versions automatically |
| `InvalidAMIID.NotFound` | AMI name patterns are region-scoped; if you change `aws_region`, update the AMI patterns too |
