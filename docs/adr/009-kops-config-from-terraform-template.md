---
title: Generate kops cluster.yaml from Terraform template
date: 2026-07-19
status: accepted
---

## Context

`terraform/kops/cluster.yaml` contains the VPC ID and subnet IDs for the kops cluster. Every `terraform destroy` + `terraform apply` creates a new VPC with new IDs, making the hardcoded values stale and causing `kops update cluster` to fail with `InvalidVpcID.NotFound`.

## Decision

Replace the static `cluster.yaml` with a Terraform `templatefile` render. A `local_file` resource in `terraform/kops.tf` renders `terraform/kops/cluster.yaml.tpl` using live Terraform outputs (VPC ID, subnet IDs, AZ names) on every `terraform apply`, overwriting `cluster.yaml` with correct values automatically.

## Consequences

- `cluster.yaml` is now a generated file and must not be hand-edited
- `terraform apply` must be run before any `kops create` or `kops replace` command
- The `local` Terraform provider (`hashicorp/local ~> 2.0`) is required
