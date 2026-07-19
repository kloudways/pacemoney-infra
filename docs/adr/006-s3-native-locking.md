# ADR 006: S3 native state locking

**Date:** 2026-07
**Status:** Accepted

## Context

Terraform remote state in S3 historically required a DynamoDB table to provide state locking and prevent concurrent applies from corrupting the state file.

Terraform 1.9 introduced native S3 state locking using conditional writes, removing the DynamoDB dependency.

## Decision

Use `use_lockfile = true` in the S3 backend configuration instead of a DynamoDB table.

```hcl
backend "s3" {
  bucket       = "kloudways-pacemoney-tfstate"
  key          = "pacemoney/terraform.tfstate"
  region       = "eu-west-2"
  use_lockfile = true
  encrypt      = true
}
```

## Consequences

- No DynamoDB table is required, reducing the number of resources to manage and the cost of the state backend (DynamoDB on-demand billing was negligible but non-zero).
- Terraform >= 1.9 is required. The `required_version` constraint in `terraform.tf` enforces this.
- Locking behaviour is equivalent to the DynamoDB approach for this project's single-operator use case.
