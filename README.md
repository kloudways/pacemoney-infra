# pacemoney-infra

Infrastructure as Code (IaC) for the Pace Money portfolio project. Manages all AWS resources: networking, compute, database, container registry, and DNS. Written in Terraform and Ansible.

## Repository structure

```
pacemoney-infra/
├── terraform/          # All AWS resources
│   ├── terraform.tf    # Backend and provider version constraints
│   ├── providers.tf    # AWS provider configuration
│   ├── variables.tf    # Input variables
│   ├── locals.tf       # Derived locals (name prefix, subnet CIDRs)
│   ├── outputs.tf      # Output values
│   ├── networking.tf   # VPC, subnets, routing, NAT gateway, Route 53
│   ├── security_groups.tf  # Security groups for ALB, app nodes, RDS
│   ├── jenkins.tf      # Jenkins EC2, EIP, IAM, Route 53 record
│   ├── rds.tf          # RDS PostgreSQL instance and subnet group
│   ├── ecr.tf          # ECR repository and lifecycle policy
│   ├── s3.tf           # Kops state bucket, S3 VPC endpoint
│   ├── iam.tf          # Kops master and node IAM roles
│   └── kops/           # Kops cluster manifest
└── ansible/            # Jenkins configuration management
    └── roles/
        ├── common/     # Base packages
        ├── docker/     # Docker installation
        ├── jenkins/    # Jenkins installation and plugins
        └── tools/      # Trivy, kops, Helm, sonar-scanner
```

## Prerequisites

- AWS CLI configured with credentials for account 684779207098
- Terraform >= 1.9
- kops
- Ansible
- kubectl

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

## Apply

```bash
cd terraform
terraform init
export TF_VAR_db_password="$(openssl rand -base64 24)"
echo $TF_VAR_db_password   # save this securely before continuing
terraform apply
```

`app_elb_hostname` is required after the Kubernetes Service creates an Elastic Load Balancer (ELB). On first apply, omit it. After the kops cluster and application are deployed, add the ELB hostname to `terraform.tfvars`:

```hcl
app_elb_hostname = "<value from kubectl get svc -n pacemoney>"
```

Then re-apply to create the Route 53 CNAME record for the application hostname.

## Destroy safely

The kops cluster must be deleted before running `terraform destroy`, otherwise kops-managed EC2 instances and security groups block VPC deletion.

```bash
# Step 1: delete the kops cluster
kops delete cluster \
  --name pacemoney.k8s.local \
  --state s3://pacemoney-kops-state \
  --yes

# Step 2: remove the kops state bucket from Terraform state
# (bucket is kept intentionally for reuse; it costs less than $0.01/month)
cd terraform
terraform state rm aws_s3_bucket.kops_state

# Step 3: destroy all remaining infrastructure
terraform destroy
```

If destroy fails on the ECR repository because it still contains images:

```bash
aws ecr delete-repository --repository-name pacemoney --force --region eu-west-2
```

Then re-run `terraform destroy`.

## Cost warning

The following resources bill hourly and should be destroyed when not in use:

| Resource | Approximate cost |
|----------|-----------------|
| NAT Gateway | $0.045/hour + data |
| RDS db.t3.micro | $0.017/hour |
| Jenkins t3.medium | $0.046/hour |
| kops EC2 nodes | varies by instance type |

Run `terraform destroy` at the end of each working session.

## Key variables

| Variable | Default | Description |
|----------|---------|-------------|
| `app_name` | `pacemoney` | Slug used in resource names and labels |
| `display_name` | `Pace Money` | Human-readable name |
| `domain_name` | `kloudways.com` | Root DNS domain |
| `aws_region` | `eu-west-2` | AWS region |
| `db_password` | (none) | RDS master password, supply via `TF_VAR_db_password` |
| `app_elb_hostname` | (none) | ELB hostname for the app Route 53 CNAME |
