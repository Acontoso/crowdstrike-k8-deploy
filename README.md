# CrowdStrike Falcon Sidecar Deployment on EKS

This repository automates the lifecycle of the CrowdStrike Falcon Container sidecar sensor for Amazon EKS by combining:

- Image synchronization from CrowdStrike Container Registry into private Amazon ECR
- Immutable digest capture for safe promotion
- Terraform-managed Helm deployment to EKS
- Environment-based promotion from dev to prod through GitHub Actions reusable workflows

The deployment target is the CrowdStrike Helm chart `falcon-sensor` in sidecar mode.

## What This Project Does

1. Pulls the latest Falcon container image from CrowdStrike registry.
2. Detects the sensor version tag that was pulled.
3. Checks whether that tag already exists in your ECR repository.
4. Pushes only when missing (idempotent behavior).
5. Resolves and outputs the immutable ECR image digest (`sha256:...`).
6. Runs Terraform plan/apply workflows for dev and prod using that exact digest.
7. Deploys the Falcon Helm chart to EKS using Terraform `helm_release`.

## Repository Layout

```text
.
├── .github/workflows/
│   ├── schedule.yml      # Pull/push/sign image, output digest, trigger plan/apply flows
│   ├── tfplan.yml        # Reusable Terraform plan workflow
│   └── tfapply.yml       # Reusable Terraform apply workflow
└── terraform/
    ├── versions.tf       # Providers, backend config, EKS auth wiring for Helm/K8s providers
    ├── main.tf           # Namespace + helm_release for Falcon sidecar
    ├── variables.tf      # Deployment inputs
    ├── outputs.tf        # Helm release outputs
    ├── crowdstrike-container.yaml  # Example Helm values overrides
    └── environments/
        ├── dev.tfvars
        └── prod.tfvars
```

## Deployment Architecture

### 1) Image Promotion Pipeline

Workflow: `.github/workflows/schedule.yml`

- Scheduled weekly and manually runnable.
- Uses GitHub OIDC to assume AWS role (no static AWS keys).
- Pulls Falcon image via CrowdStrike script.
- Uses ECR as source of truth for digest output.
- Exposes job outputs:
  - `image_sha`
  - `image_uri`

### 2) Terraform Plan and Apply

Reusable workflows:

- `.github/workflows/tfplan.yml`
- `.github/workflows/tfapply.yml`

Each reusable workflow receives:

- `environment` (for example `dev`, `prod`)
- `image_digest` (from the image pipeline job output)

Each workflow:

1. Assumes AWS role via OIDC
2. Runs Terraform init using S3 backend + DynamoDB lock table
3. Validates Terraform
4. Runs plan or apply with environment tfvars and image digest

### 3) Terraform -> Helm -> EKS

Terraform uses:

- `data.aws_eks_cluster` and `data.aws_eks_cluster_auth` for cluster endpoint + token
- `provider "kubernetes"` and `provider "helm"` configured directly from EKS data sources

The Helm release deploys Falcon sidecar with critical chart values:

- `container.image.repository = var.container_image_repository`
- `container.image.digest = var.container_image_digest`
- `falcon.cid = var.falcon_cid` (sensitive)

This pins workload rollout to an immutable digest, which is production-safe and repeatable.

## Prerequisites

### AWS / EKS

1. EKS cluster exists and is reachable.
2. GitHub OIDC trust relationship is configured in AWS IAM.
3. IAM roles used by workflows have required permissions for:
   - ECR (pull/push/describe)
   - EKS describe cluster
   - Terraform-managed resources
   - S3 state bucket and DynamoDB lock table
4. The IAM role is authorized to deploy into Kubernetes (EKS access entries or equivalent RBAC mapping).

### CrowdStrike

1. Valid CrowdStrike API credentials.
2. Access to pull Falcon container images from CrowdStrike registry.
3. Falcon CID for your tenant.

## Required GitHub Secrets

At minimum, configure these secrets:

- `AWS_ACCOUNT_ID`
- `TF_STATE_BUCKET`
- `TF_LOCK_TABLE`
- `REGISTRY` (example: `123456789012.dkr.ecr.ap-southeast-2.amazonaws.com`)
- `REPOSITORY` (example: `falcon-sensor`)
- `FALCON_CLIENT_ID`
- `FALCON_CLIENT_SECRET`
- `FALCON_REGION`

You may also use environment-scoped secrets for dev/prod where needed.

## Terraform Inputs

Main variables used by this deployment:

- `aws_region`
- `cluster_name`
- `release_name`
- `namespace`
- `chart_repository` (default: CrowdStrike Helm repo)
- `chart_name` (default: `falcon-sensor`)
- `chart_version` (optional pin)
- `falcon_cid` (sensitive)
- `container_image_repository`
- `container_image_digest`

Environment-specific values belong in:

- `terraform/environments/dev.tfvars`
- `terraform/environments/prod.tfvars`

Example tfvars baseline:

```hcl
aws_region                  = "ap-southeast-2"
cluster_name                = "your-eks-cluster"
release_name                = "falcon-helm"
namespace                   = "falcon-system"
create_namespace            = true

container_image_repository  = "123456789012.dkr.ecr.ap-southeast-2.amazonaws.com/falcon-sensor"
falcon_cid                  = "YOUR_CID"

# Set by CI/CD promotion pipeline
# container_image_digest = "sha256:..."
```

## Local Terraform Usage

From the `terraform` directory:

```bash
terraform init \
  -backend-config="bucket=<state-bucket>" \
  -backend-config="key=statefiles/dev/falcon-sidecar.tfstate" \
  -backend-config="region=ap-southeast-2" \
  -backend-config="dynamodb_table=<lock-table>" \
  -backend-config="encrypt=true"

terraform validate

terraform plan \
  -var-file="environments/dev.tfvars" \
  -var "container_image_digest=sha256:<digest>"

terraform apply \
  -var-file="environments/dev.tfvars" \
  -var "container_image_digest=sha256:<digest>"
```

## Production Promotion Strategy

Recommended strategy used by this repo:

1. Pull and publish image once.
2. Capture digest once from ECR.
3. Deploy same digest to dev.
4. After approval, deploy same digest to prod.

This guarantees prod runs exactly what was validated in dev.

## Important Notes

1. The Terraform workflows currently pass a variable named `image_digest`. The Helm Terraform module expects `container_image_digest`. Ensure these names are aligned in workflows and Terraform CLI arguments.
2. For production stability, pin `chart_version` instead of floating latest.
3. Keep `falcon.cid` managed as sensitive data (never commit to repository).
4. Use GitHub Environment protections for prod apply (required approvers, branch restrictions).
