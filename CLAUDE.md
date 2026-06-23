# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal AWS infrastructure-as-code repository. Uses a feature-flag pattern via YAML variables to enable/disable AWS services, keeping costs low when services aren't needed.

## Commands

### OpenTofu (primary IaC)

```bash
# From .local/ directory (sets AWS_PROFILE and TF_VARs):
.local/release.sh init    # Initialize backend
.local/release.sh plan    # Plan changes (workspace: awsing)
.local/release.sh apply   # Apply changes

# Direct tofu commands (from tofu/ directory):
tofu plan -var-file=vars/.vars.tfvars
tofu apply -var-file=vars/.vars.tfvars
```

### CDK (bootstrapping only — S3 backend bucket)

```bash
cd cdk
pip install -r requirements.txt
cdk synth
cdk deploy
```

## Architecture

Two IaC layers with distinct purposes:

1. **`cdk/`** — AWS CDK (Python). Only provisions the S3 backend bucket that OpenTofu uses for state storage. Rarely modified.

2. **`tofu/`** — OpenTofu (primary). All AWS infrastructure lives here. Uses the `terraform-aws-modules` registry exclusively.

### OpenTofu structure

- **`main.tofu`** — Backend config (S3), AWS provider with assume-role, Kubernetes provider (conditional on EKS)
- **`variables.tofu`** — Input variables (account_id, iac_role, s3_backend, aws_region)
- **`locals.tofu`** — Loads YAML config files; template vars for interpolation
- **`vars/vars.yaml`** — Feature flags and module versions. The `create` booleans control whether resources exist.
- **`vars/cloudfront.yaml`**, **`vars/s3.yaml`** — Templated YAML (uses `templatefile()`) for complex resource configs
- **`vars/.vars.tfvars`** — Sensitive variables (gitignored)

### Feature-flag pattern

All modules check a `create` flag from `vars/vars.yaml`:
```hcl
create = local.vars.eks.create
```
To enable/disable a service, toggle its flag in `vars/vars.yaml` and run plan/apply.

### Workspace convention

The OpenTofu workspace name (`awsing`) is used as a prefix for all resource names: `${terraform.workspace}-<resource>`.

### Module versions

Pinned in `vars/vars.yaml` under `versions:`. When updating a module, change the version there — all `.tofu` files reference `local.vars.versions.<module>`.

### Key services

| File | Service | Notes |
|------|---------|-------|
| `vpc.tofu` | VPC | 3-tier subnets (public/private/intra), NAT gateway toggleable |
| `eks.tofu` | EKS | Fargate profiles, CoreDNS on Fargate, OIDC |
| `ecs.tofu` | ECS | Fargate + Fargate Spot (50/50 weight) |
| `rds.tofu` | Aurora PostgreSQL | Engine v17, manages master password via `random_password` |
| `ec2.tofu` | EC2 | SSM-managed instances (AL2023 ARM64) |
| `s3.tofu` | S3 | Driven by `vars/s3.yaml`, optional KMS encryption |
| `cloudfront.tofu` | CloudFront | Driven by `vars/cloudfront.yaml`, OAC for S3 origins |
| `efs.tofu` | EFS | Conditional on EKS EFS CSI driver addon |
| `iam.github_oidc.tofu` | GitHub OIDC | Federated access for CI/CD from specified repos |
| `lambda.aurora-clone.tofu` | Lambda | Python 3.13, clones Aurora clusters (source in `tofu/src/`) |

### Authentication

Uses IAM role assumption (`awsing-github-awsing-role`) with AdministratorAccess. GitHub Actions authenticate via OIDC federation. Local dev uses `AWS_PROFILE=awsing-admin`.

## Git Conventions

Branch names use the format `<type>/<description>`:
- `chore/` — maintenance, dependency updates, non-functional changes
- `feature/` — new infrastructure or capabilities
- `release/` — release preparation
- `fix/` — bug fixes or corrective changes
