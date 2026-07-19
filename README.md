# pacemoney-infra

Infrastructure as Code (IaC) for the Pace Money portfolio project. Manages all AWS resources: networking, compute, database, container registry, secrets, and DNS. Written in Terraform and Ansible.

## Repository structure

```
pacemoney-infra/
├── terraform/
│   ├── terraform.tf        # Backend and provider version constraints
│   ├── providers.tf        # AWS provider configuration
│   ├── variables.tf        # Input variables
│   ├── locals.tf           # Derived locals (name prefix, subnet CIDRs)
│   ├── outputs.tf          # Output values
│   ├── networking.tf       # VPC, subnets, routing, NAT gateway, Route 53
│   ├── security_groups.tf  # Security groups for ALB, app nodes, RDS, Jenkins
│   ├── jenkins.tf          # Jenkins EC2, EIP, IAM, Route 53 record
│   ├── rds.tf              # RDS PostgreSQL instance and subnet group
│   ├── ecr.tf              # ECR repository and lifecycle policy
│   ├── s3.tf               # Kops state bucket, S3 VPC endpoint
│   ├── iam.tf              # Kops master and node IAM roles
│   ├── secrets.tf          # AWS Secrets Manager secret for the database URL
│   ├── kops.tf             # Generates kops/cluster.yaml from live Terraform outputs
│   └── kops/
│       ├── cluster.yaml.tpl    # Kops cluster manifest template
│       └── instancegroups.yaml # Kops instance group definitions
├── ansible/                # Jenkins configuration management
│   └── roles/
│       ├── common/         # Base packages (Python, git, etc.)
│       ├── docker/         # Docker installation
│       ├── java/           # Java (Jenkins dependency)
│       ├── jenkins/        # Jenkins installation
│       └── toolchain/      # Trivy, kops, Helm, kubectl, sonar-scanner
└── monitoring/
    ├── kube-prometheus-stack-values.yaml  # Helm values for Prometheus + Grafana
    └── argocd-values.yaml                 # Helm values for ArgoCD
```

## Prerequisites

- AWS CLI configured with credentials for account `684779207098`
- Terraform >= 1.9
- kops
- Ansible
- kubectl
- Helm 3

## Bootstrap: create the Terraform state bucket

The state bucket must exist before running `terraform init`. Create it once:

```bash
aws s3api create-bucket \
  --bucket kloudways-pacemoney-tfstate \
  --region eu-west-2 \
  --create-bucket-configuration LocationConstraint=eu-west-2

aws s3api put-bucket-versioning \
  --bucket kloudways-pacemoney-tfstate \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket kloudways-pacemoney-tfstate \
  --server-side-encryption-configuration \
    '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
```

## Daily startup

See `docs/runbook.md` for the complete step-by-step startup sequence. Summary:

1. `terraform apply` — creates all AWS resources including the Secrets Manager secret
2. Ansible — configures the Jenkins EC2 instance
3. kops — creates the Kubernetes cluster
4. Helm — installs kube-prometheus-stack, External Secrets Operator, and ArgoCD
5. ArgoCD Application bootstrap — `kubectl apply` the manifest from pacemoney-app
6. Jenkins pipeline — builds the image; ArgoCD deploys it

## Apply

Create `terraform/terraform.tfvars` (gitignored — never commit this file):

```hcl
db_password      = "<generate with: openssl rand -base64 24>"
app_elb_hostname = "<from kubectl get svc -n pacemoney after first deploy>"
```

Then:

```bash
cd terraform
terraform init
terraform apply
```

`app_elb_hostname` is only needed after the first Kubernetes deploy. On first apply, omit it or leave it blank and re-apply once you have the ELB hostname.

## Secrets management

The database connection string is stored in AWS Secrets Manager under `pacemoney/db-url`. Terraform constructs and writes this value on every `apply` from the RDS endpoint, username, password, and database name. The kops node IAM role is granted read access to this specific secret.

In the cluster, the External Secrets Operator (ESO) reads the secret and creates a Kubernetes Secret in the `pacemoney` namespace. Application pods consume it via a `secretKeyRef` — no secret ever passes through Jenkins.

## Destroy safely

The kops cluster must be deleted before running `terraform destroy`, otherwise kops-managed resources block VPC deletion.

```bash
# Step 1: delete the kops cluster
kops delete cluster \
  --name pacemoney.k8s.local \
  --state s3://pacemoney-kops-state \
  --yes

# Step 2: remove the kops state bucket from Terraform state
# (bucket is kept for reuse; costs <$0.01/month)
cd terraform
terraform state rm aws_s3_bucket.kops_state

# Step 3: destroy all remaining infrastructure
terraform destroy
```

If destroy fails on ECR because it still contains images:

```bash
aws ecr delete-repository --repository-name pacemoney --force --region eu-west-2
```

## Cost warning

The following resources bill hourly and should be destroyed when not in use:

| Resource | Approximate cost |
|----------|-----------------|
| NAT Gateway | $0.045/hour + data |
| RDS db.t3.micro | $0.017/hour |
| Jenkins t3.medium | $0.046/hour |
| kops EC2 nodes | varies by instance type |

Run the teardown steps in `docs/runbook.md` at the end of each working session.

## Key variables

| Variable | Default | Description |
|----------|---------|-------------|
| `app_name` | `pacemoney` | Slug used in resource names and labels |
| `display_name` | `Pace Money` | Human-readable name |
| `domain_name` | `kloudways.com` | Root DNS domain |
| `aws_region` | `eu-west-2` | AWS region |
| `db_password` | (required) | RDS master password — set in `terraform.tfvars` (gitignored) |
| `app_elb_hostname` | (required) | ELB hostname for the app Route 53 CNAME — set after first deploy |

## Documentation

| Document | Contents |
|----------|----------|
| `docs/architecture.md` | VPC layout, compute, networking, IAM, security groups |
| `docs/runbook.md` | Daily startup and teardown procedures, troubleshooting |
| `docs/issues-log.md` | Issues encountered during each phase and their fixes |
| `docs/adr/` | Architecture decision records |
