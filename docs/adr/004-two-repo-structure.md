# ADR 004: Two-repository structure

**Date:** 2026-07
**Status:** Accepted

## Context

The project has two distinct concerns: infrastructure (AWS resources, Kubernetes cluster, Ansible configuration) and the application (Python code, Helm chart, Jenkinsfile). These could be co-located in a monorepo or kept in separate repositories.

## Decision

Maintain two separate GitHub repositories:

- `kloudways/pacemoney-infra`: all infrastructure
- `kloudways/pacemoney-app`: application code, Helm chart, and Jenkins pipeline

## Consequences

- Infrastructure changes can be reviewed, versioned, and deployed independently of application changes.
- The Jenkins pipeline in `pacemoney-app` does not need write access to the infrastructure repository.
- Gitleaks scans each repository independently, reducing the chance of a false negative from a large mixed-concern repository.
- Developers working on application code do not see infrastructure noise in their pull request history.
- Cross-cutting changes (for example, adding a new environment variable that requires both an RDS parameter and an app config change) require coordinated pull requests in two repositories.
