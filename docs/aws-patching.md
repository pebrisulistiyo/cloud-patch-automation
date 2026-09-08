# AWS Patching, Demo Walkthrough

How to run a full cloud-patch-automation demo session on AWS and capture the
evidence for the portfolio. Budget: **~30 minutes** + one email confirmation.

## 0. Prerequisites

- The `aws/` infra already applied (baselines, windows, reporting), VMs off.
- AWS credentials for the apply role (or run from GitHub Actions on main).
- Your alert email confirmed for the SNS subscription.

## 1. Spin up the demo fleet

```bash
cd aws
cp terraform.tfvars.example terraform.tfvars
# edit: enable_demo_vms = true

terraform apply
```

Creates:
- `patch-demo-linux`, Amazon Linux 2023, t3.micro
- `patch-demo-windows`, Windows Server 2022, t3.small

Both are SSM-managed (no SSH keys) and tagged `Patch Group = demo`.

## 2. Wait for the agent to check in

~5–15 minutes after launch, both instances should appear in
**Systems Manager to Fleet Manager** as "SSM Agent online" and "Managed".

```bash
aws ssm describe-instance-information --query 'InstanceInformationList[].{Instance:InstanceId, Ping:PingStatus, Agent:AgentVersion}'
```

## 3. Run a scan on demand (don't wait for Saturday)

**Systems Manager to Patch Manager to Patch now**, or via CLI:

```bash
aws ssm send-command \
  --document-name "AWS-RunPatchBaseline" \
  --targets "Key=tag:Patch Group,Values=demo" \
  --parameters '{"Operation":["Scan"]}' \
  --timeout-seconds 600
```

## 4. Capture evidence (screenshots)

- [ ] **Patch Manager to Compliance**, both instances listed, patch group
      `demo`, baseline shown per OS, compliance summary (missing patches count).
- [ ] **Patch Manager to Baselines**, the two custom baselines with the
      3-day approval delay visible.
- [ ] **S3**, `patch-compliance-<account>` bucket contains the resource data
      sync output under `patch-compliance/`.
- [ ] **Inbox**, the EventBridge to SNS email alert on compliance state change.
- [ ] **Maintenance windows**, weekly scan + monthly install schedules.

Paste all of these into the README evidence table.

## 5. Install demo (optional, but proves the loop)

Trigger the install task through the maintenance window or run on demand with
`Operation=Install, RebootOption=RebootIfNeeded`. Watch compliance flip to
green in Patch Manager.

> Note: the install will reboot the Windows instance and can take 10+ minutes on a
> fresh Windows Server (dozens of updates). Budget time accordingly.

## 6. Tear down

```bash
terraform apply -var='enable_demo_vms=false'   # or: terraform destroy
```

Verify with the root-repo DESTROY-CHECKLIST. The baselines/windows/reporting
are ~$0/mo and can stay applied.
