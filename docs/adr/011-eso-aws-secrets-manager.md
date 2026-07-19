---
title: Manage database credentials with External Secrets Operator and AWS Secrets Manager
date: 2026-07-19
status: accepted
---

## Context

The database connection string was previously injected at Helm deploy time from a Jenkins credential (`db-url`). This meant the secret was stored in Jenkins, passed on the command line, and had no rotation path. With ArgoCD taking over deployment, Jenkins no longer runs `helm upgrade` — so there is no opportunity to inject the secret at deploy time.

## Decision

Store the database URL in AWS Secrets Manager under the key `pacemoney/db-url`. The value is constructed by Terraform from the RDS endpoint, username, password, and database name, and written to Secrets Manager on every `terraform apply`.

Install the External Secrets Operator (ESO) in the cluster. Each Helm release for the application includes a `SecretStore` (pointing at AWS Secrets Manager in eu-west-2) and an `ExternalSecret` (mapping `pacemoney/db-url` to a Kubernetes Secret named `pacemoney-pacemoney-db`). ESO syncs the secret into the namespace and refreshes it every hour.

The kops node IAM role (`pacemoney-kops-node`) is granted `secretsmanager:GetSecretValue` and `secretsmanager:DescribeSecret` on the specific secret ARN. ESO uses the node's instance profile — no separate IAM user or IRSA required.

## Consequences

- The `db-url` Jenkins credential is no longer needed and should be removed from Jenkins
- The Jenkins `github-token` credential (for image-tag commits) replaces it as the only sensitive credential Jenkins holds
- Any other application or cluster with the correct IAM permission on `pacemoney/db-url` can consume the same secret
- Secret rotation requires updating the value in Secrets Manager (or re-running `terraform apply` with a new `db_password`); ESO picks up the new value within the refresh interval
