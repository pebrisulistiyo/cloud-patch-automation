# Multi-Cloud Patch Management

Automated OS patching and vulnerability remediation for **Linux and Windows**
on two clouds, managed end-to-end with Terraform and GitHub Actions.

| Cloud | Service | Status |
|-------|---------|--------|
| AWS | Systems Manager **Patch Manager** (baselines, maintenance windows, compliance export, alerts) | Live |
| GCP | Compute Engine **VM Manager** (OS patch deployments, instance schedules) | Code-first (deploy-ready, applied when the GCP account exists) |

![terraform](https://img.shields.io/badge/Terraform-%3E%3D1.15-844FBA)
![aws](https://img.shields.io/badge/AWS-us--east--1-FF9900)
![gcp](https://img.shields.io/badge/GCP-asia--southeast1-4285F4)
![ci](https://img.shields.io/github/actions/workflow/status/pebrisulistiyo/cloud-patch-automation/terraform-ci.yml?label=terraform-ci)

---

## Architecture

```mermaid
flowchart LR
    subgraph AWS[AWS, live]
        BL[Patch baselines<br/>Linux + Windows]
        MW[Maintenance windows<br/>scan weekly / install monthly]
        VM1[Amazon Linux 2023<br/>t3.micro spot]
        VM2[Windows Server 2025<br/>t3.small spot]
        S3[(Compliance export<br/>S3 + Athena-ready)]
        SNS[Email alerts]
        MW --> VM1 & VM2
        BL --> MW
        VM1 & VM2 -. compliance .-> S3
        VM1 & VM2 -. state change .-> SNS
    end

    subgraph GCP[GCP, code-first]
        PD[OS patch deployments<br/>apt + Windows Update]
        VM3[Debian 13<br/>e2-micro]
        VM4[Windows Core 2025<br/>e2-small]
        SCHED[Instance schedule<br/>stop outside business hours]
        PD --> VM3 & VM4
        SCHED --> VM3 & VM4
    end

    GHA[GitHub Actions<br/>lint to fmt to validate to plan to apply] --> AWS & GCP
```

**The same pattern on both clouds:** a patch policy per OS family to a schedule
that enforces it to reporting you can prove compliance with. The mechanics
differ (SSM baselines vs OS patch deployments), the platform-engineering
problem is identical.

## What's inside

```
cloud-patch-automation/
├── aws/                 # Terraform, SSM Patch Manager (LIVE)
│   ├── ssm.tf           #   patch baselines, maintenance windows, tasks, inventory
│   ├── instances.tf     #   demo VMs (opt-in via enable_demo_vms)
│   ├── reporting.tf     #   S3 resource data sync + EventBridge to SNS email alerts
│   └── iam.tf           #   instance role (AmazonSSMManagedInstanceCore only)
├── gcp/                 # Terraform, VM Manager (code-first)
│   ├── osconfig.tf      #   monthly patch deployments (apt + Windows Update)
│   └── instances.tf     #   demo VMs + instance schedule (cost guardrail)
├── .github/workflows/terraform-ci.yml
└── docs/
    ├── aws-patching.md  # AWS demo guide: setup to destroy + evidence checklist
    └── gcp-patching.md  # runbook for when the GCP account arrives
```

## Key decisions

- **3-day auto-approval delay** on every patch baseline, if AWS/GCP pulls a
  bad patch, the fleet never sees it. This is the "canary" of patching.
- **Windows is a first-class citizen**, `UpdateRollups` classification on AWS,
  `UPDATE_ROLLUP` on GCP. Most patch demos are Linux-only; production fleets
  are not.
- **Every instance is tagged `os` + `os_version`** (e.g. `os=windows`,
  `os_version=2016`) on top of `Patch Group`, and each OS version gets its own
  patch group (`demo-windows-2025`, `demo-linux-2023`). Multi-version fleets
  stay filterable in Tag Editor, Resource Groups, and the S3 compliance
  export, and a legacy version can get its own baseline or schedule without
  touching the rest. AMI versions are variables, so trying another version
  is a tfvars edit, not a code change.
- **No SSH/RDP keys anywhere**, instances are SSM/OS-Config-agent managed
  only. Patch jobs reach the agent outbound; humans use Session Manager.
- **Demo VMs are opt-in** (`enable_demo_vms = false` by default) and the GCP
  fleet is additionally stopped outside business hours by an instance
  schedule, patching infra should be reviewable without burning money.
- **Demo VMs run on Spot** (`enable_spot = true` default): ~60–70% cheaper,
  with the price capped at on-demand, so the cost table below is the worst
  case. Interruption is possible but rare for `t3.micro`/`t3.small` — a
  reclaimed demo VM is recreated by the next apply.
- **Compliance is exportable, not just screenshot-able**, SSM resource data
  sync streams JSON to S3 (Athena-queryable); GCP exposes OS Inventory in the
  console.

## CI/CD pipeline

`terraform-ci.yml` runs on every PR touching `aws/**` or `gcp/**`:

| Job | Trigger | Auth |
|-----|---------|------|
| `lint` (tflint + actionlint) | PR / main | none |
| `fmt` (`terraform fmt -check`) | PR / main | none |
| `validate` (aws + gcp, `-backend=false`) | PR / main | **none, this is how code-first GCP proves deploy-readiness** |
| `plan-aws` to comments plan on the PR | PR | GitHub OIDC to read-only `plan` role |
| `apply-aws` | main | GitHub OIDC to main-only `apply` role |
| `gcp` (plan/apply, manual) | workflow_dispatch | self-skips until GCP variables exist, see [gcp-patching.md](docs/gcp-patching.md) |

No static AWS keys anywhere. Roles are provisioned by
[terraform-bootstrap](https://github.com/pebrisulistiyo/terraform-bootstrap).

## Local usage

```bash
# AWS (live)
cd aws
cp terraform.tfvars.example terraform.tfvars
terraform init                           # local state on disk, no S3 bucket needed
#   remote state (CI path), only when you want the shared bucket:
#     cp backend.tf.example backend.tf && cp backend.hcl.example backend.hcl
#     && terraform init -backend-config=backend.hcl
terraform plan
terraform apply                          # infra only, VMs stay off

# GCP (code-first: validate only, no account needed)
cd gcp
terraform init && terraform validate
```

### Demo session (AWS)

Full step-by-step guide from zero to destroy, with the screenshot checklist:
**[docs/aws-patching.md](docs/aws-patching.md)**.

## Cost model (approximate, us-east-1 / asia-southeast1)

| Item | ~Cost if running 24/7 | Guardrail |
|------|----------------------|-----------|
| Amazon Linux 2023 `t3.micro` | ~$7.60/mo | `enable_demo_vms=false`; destroy after demo |
| Windows Server 2025 `t3.small` | ~$40–45/mo | same + AWS budgets ($20/$50/$80) from bootstrap |
| Debian 13 `e2-micro` | ~$5.60/mo | instance schedule stops it outside business hours |
| Windows Core 2025 `e2-small` | ~$45–50/mo | same + GCP billing budget $10/mo (when account arrives) |
| SSM / VM Manager / S3 / SNS | $0 at demo volume |, |

OS versions are configurable on both clouds (`linux_ami` / `windows_ami`
variables on AWS), so the cost table follows whatever version you demo.
Rates shown are on-demand; the AWS demo fleet runs on Spot by default
(`enable_spot`), typically 60–70% below these numbers.

## Evidence (screenshots)

| AWS Patch Manager compliance | S3 compliance export | GCP VM Manager patch jobs |
|------------------------------|----------------------|---------------------------|
| pending, to be captured in demo session | pending | pending (after GCP account arrives) |

## Trade-offs worth mentioning

- **Compliance data goes to S3, not a warehouse**, Athena can query it in
  place; a dedicated warehouse would be overkill for a demo.
- **One patch group per OS version, not one per fleet**, so compliance,
  schedules, and alerts are trackable per version, and adding Windows 2016
  next to Windows 2025 is one tfvars edit (per-version groups make a
  version-specific baseline possible later, e.g. a longer approval soak for
  legacy OSes).
- **GCP reporting is console-based (OS Inventory)**, lean;
  exporting to BigQuery would be the natural next step.
