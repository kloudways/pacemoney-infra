---
title: Use kops additionalPolicies to grant Secrets Manager access instead of manual aws iam put-role-policy
date: 2026-07-20
status: accepted
---

## Context

Phase 8 (ADR 014) identified that kops creates its own IAM role (`nodes.pacemoney.k8s.local`) on every `kops update cluster --yes`, which replaces the Terraform-managed role. The workaround was to run `aws iam put-role-policy` after each cluster creation to attach the Secrets Manager inline policy.

This step was manual and easy to forget. Forgetting it caused ESO `AccessDeniedException` errors on every fresh cluster.

## Decision

Add `additionalPolicies.node` to `terraform/kops/cluster.yaml.tpl`. kops applies this policy to the node role during `kops update cluster --yes`, so the Secrets Manager permission is baked in and requires no manual step.

The `db_url_secret_arn` value is passed from `aws_secretsmanager_secret.db_url.arn` via the `templatefile()` call in `terraform/kops/kops.tf`, so the correct ARN is always used.

## Consequences

- The manual `aws iam put-role-policy` step is removed from the runbook.
- The IMDS hop limit (`--http-put-response-hop-limit 2`) still requires a manual post-cluster step — it is a node-level EC2 metadata option, not an IAM policy.
- The Terraform-managed `pacemoney-kops-node` role and instance profile remain in Terraform state but serve no function for kops nodes (see ADR 014). Removing them is deferred.
