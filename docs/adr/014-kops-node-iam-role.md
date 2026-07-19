---
title: Add Secrets Manager policy to kops-managed node role, not Terraform-managed role
date: 2026-07-19
status: accepted
---

## Context

Terraform manages an IAM role named `pacemoney-kops-node` with an inline policy that includes `secretsmanager:GetSecretValue`. The expectation was that kops nodes would use this role.

In practice, `kops update cluster --yes` creates its own IAM role named `nodes.pacemoney.k8s.local` and attaches it to the worker node instances via a kops-managed instance profile. The Terraform-managed `pacemoney-kops-node` role is not used by the nodes.

When ESO attempted to call `GetSecretValue`, the request was rejected with:

```
AccessDeniedException: User: arn:aws:sts::684779207098:assumed-role/nodes.pacemoney.k8s.local/...
is not authorized to perform: secretsmanager:GetSecretValue
```

## Decision

Add the Secrets Manager policy directly to the kops-managed role `nodes.pacemoney.k8s.local` as an inline policy via `aws iam put-role-policy`. This is the role actually attached to the nodes.

The Terraform-managed `pacemoney-kops-node` role and instance profile remain in state but serve no function for kops nodes. Removing them is deferred to avoid unnecessary Terraform churn.

## Permanent fix

The `aws iam put-role-policy` step is not persistent — kops recreates the role on every `kops update cluster --yes`. The durable fix is to use kops `additionalPolicies` in `cluster.yaml`:

```yaml
spec:
  additionalPolicies:
    node: |
      [
        {
          "Effect": "Allow",
          "Action": ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"],
          "Resource": "arn:aws:secretsmanager:eu-west-2:<account>:secret:pacemoney/db-url-*"
        }
      ]
```

This is the correct long-term approach and is tracked as a follow-up for Phase 9.

## Consequences

Until `additionalPolicies` is wired in, the runbook must include the `aws iam put-role-policy` step after every cluster creation.
