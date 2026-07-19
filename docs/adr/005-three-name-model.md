# ADR 005: Three-variable naming model

**Date:** 2026-07
**Status:** Accepted

## Context

Infrastructure resources need names. Hardcoding the application name as a literal string in Terraform creates friction when the project is renamed or cloned for a different application.

## Decision

Drive all naming from three Terraform variables:

| Variable | Value | Used for |
|----------|-------|---------|
| `app_name` | `pacemoney` | Resource names, S3 bucket names, ECR repository name, Kubernetes namespace, Helm release name, IAM role names |
| `display_name` | `Pace Money` | SonarCloud project name, FastAPI title |
| `domain_name` | `kloudways.com` | Route 53 records, Jenkins URL, application hostname |

The `locals.tf` file derives `name_prefix = var.app_name`, which is then used as a prefix in all resource name strings.

## Consequences

- No hardcoded application name literals appear in any `.tf` file.
- Renaming the application or cloning the configuration for a new project requires changing only the three variable defaults in `variables.tf`.
- The naming pattern is consistent and predictable: `pacemoney-jenkins-sg`, `pacemoney-rds`, `pacemoney-kops-state`, and so on.
- The `display_name` separation avoids camel-case or title-case strings appearing in infrastructure resource names, which some AWS services do not support.
