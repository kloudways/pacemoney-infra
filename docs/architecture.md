# Architecture

## Overview

All resources live in a single AWS region (eu-west-2, London) inside a single Virtual Private Cloud (VPC). The VPC is divided into three subnet tiers to enforce network isolation between compute, Kubernetes nodes, and the database.

## VPC and networking

**VPC CIDR:** 10.1.0.0/16

Three tiers, three Availability Zones (AZs) each, giving nine subnets total:

| Tier | CIDRs | Purpose | Internet route |
|------|-------|---------|---------------|
| Public | 10.1.1.0/24, 10.1.2.0/24, 10.1.3.0/24 | Jenkins EIP, NAT gateway | Internet gateway (direct) |
| Private | 10.1.11.0/24, 10.1.12.0/24, 10.1.13.0/24 | kops Kubernetes nodes | NAT gateway (egress only) |
| Isolated | 10.1.21.0/24, 10.1.22.0/24, 10.1.23.0/24 | RDS PostgreSQL | None |

An S3 gateway VPC endpoint covers all three route tables, so S3 traffic (kops state, ECR layer pulls) does not leave the AWS network.

## Jenkins

- EC2 instance: `t3.medium`, Ubuntu 22.04, 30 GB gp3 encrypted root volume
- Placed in a public subnet with an Elastic IP (EIP)
- Route 53 A record: `jenkins.kloudways.com` -> EIP
- Security group: SSH from operator IP only, port 8080 open to the internet for the UI and GitHub webhooks
- IAM instance profile: `AmazonEC2ContainerRegistryPowerUser` (managed policy) plus an inline policy granting kops read-only permissions (EC2, ELB, Auto Scaling Describe*) and S3 read/write on both state buckets

## Kubernetes cluster (kops)

- Cluster name: `pacemoney.k8s.local` (gossip DNS mode, no Route 53 hosted zone required for the cluster)
- Private topology: control plane and nodes in private subnets, no public IPs on nodes
- Control plane: one master in eu-west-2a
- Workers: one node group spanning eu-west-2a, eu-west-2b, eu-west-2c
- kops manages its own security groups (`masters.pacemoney.k8s.local`, `nodes.pacemoney.k8s.local`)
- kops state stored in S3: `pacemoney-kops-state` (versioned, encrypted, public access blocked)

### In-cluster components

| Namespace | Component | Purpose |
|-----------|-----------|---------|
| `monitoring` | kube-prometheus-stack | Prometheus, Grafana, AlertManager, Prometheus Operator |
| `external-secrets` | External Secrets Operator | Syncs AWS Secrets Manager secrets into Kubernetes Secrets |
| `argocd` | ArgoCD | GitOps continuous delivery; watches `main` branch and syncs the pacemoney Helm release |
| `pacemoney` | pacemoney app | The application itself, deployed by ArgoCD |

## RDS

- Engine: PostgreSQL 16
- Instance class: `db.t3.micro`
- Storage: 20 GB gp2, encrypted at rest
- Placed in isolated subnets, not publicly accessible
- Security group: port 5432 allowed from `app_node_sg` and from the VPC CIDR (10.1.0.0/16) to cover kops-managed node security groups
- Backup retention: 7 days

## AWS Secrets Manager

- One secret: `pacemoney/db-url` — the full PostgreSQL connection string for the RDS instance
- Created and updated by Terraform on every apply; value is constructed from `db_username`, `db_password`, and the RDS endpoint
- `recovery_window_in_days = 0` (immediate deletion on destroy, appropriate for a lab)
- Accessed by kops worker nodes via the `pacemoney-kops-node` IAM role (no separate IAM user)

## ECR

- Repository name: `pacemoney`
- Image scanning on push: enabled
- Encryption: AES256
- Lifecycle policy: untagged images expire after 1 day, maximum 30 tagged images retained

## S3 buckets

| Bucket | Purpose | Managed by |
|--------|---------|-----------|
| `kloudways-pacemoney-tfstate` | Terraform remote state | Pre-existing (created manually) |
| `pacemoney-kops-state` | kops cluster state store | Terraform |

Both buckets have versioning enabled, AES256 encryption, and public access blocked.

## Route 53

The hosted zone `kloudways.com` (zone ID Z07018212GUXSW884XFQV) is not managed by this Terraform configuration. Two records are managed:

| Record | Type | Target |
|--------|------|--------|
| `jenkins.kloudways.com` | A | Jenkins EIP |
| `pacemoney.kloudways.com` | CNAME | kops-provisioned ELB hostname |

## Application traffic path

```
Internet
  -> ELB (port 80, kops-provisioned Classic ELB, internet-facing)
  -> kops node (NodePort 31132, private subnet)
  -> pod (port 8000, uvicorn)
```

The Kubernetes Service uses `type: LoadBalancer`. kops provisions a Classic ELB automatically. The ELB hostname is added to `terraform.tfvars` and a Route 53 CNAME record points `pacemoney.kloudways.com` at it.

## Security groups

| Security group | Inbound | Outbound |
|---------------|---------|---------|
| `pacemoney-alb-sg` | 80 from 0.0.0.0/0, 443 from 0.0.0.0/0 | All |
| `pacemoney-app-node-sg` | App port from ALB SG | All |
| `pacemoney-rds-sg` | 5432 from app-node-sg, 5432 from 10.1.0.0/16 | All |
| `pacemoney-jenkins-sg` | 22 from operator IP, 8080 from 0.0.0.0/0 | All |

## IAM roles

| Role | Used by | Permissions |
|------|---------|------------|
| `pacemoney-kops-master` | kops control plane nodes | EC2:*, ELB:*, Route 53 change sets, S3:*, IAM instance profile management |
| `pacemoney-kops-node` | kops worker nodes | EC2 Describe*, S3 read on kops state, ECR read-only, Secrets Manager GetSecretValue on `pacemoney/db-url` |
| `pacemoney-jenkins` | Jenkins EC2 | ECR power user, kops read-only (EC2/ELB/AS Describe*), S3 read/write on state buckets |
