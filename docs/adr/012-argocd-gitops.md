---
title: Replace Helm Deploy stage with ArgoCD GitOps delivery
date: 2026-07-19
status: accepted
---

## Context

The Jenkins pipeline previously ran `helm upgrade --install` directly from the pipeline (CI/CD in one process). This couples build and deploy — any failure in the deploy stage blocks the next build, and the cluster state is only reconciled when Jenkins runs, not continuously.

## Decision

Install ArgoCD in the cluster (`argocd` namespace, exposed via LoadBalancer). The `Application` manifest at `deploy/argocd/application.yaml` points ArgoCD at the `deploy/helm/pacemoney` path on the `main` branch of the pacemoney-app repo. ArgoCD polls git every three minutes and automatically syncs when a change is detected.

Jenkins no longer runs `helm upgrade`. Instead, after a successful image push to ECR, Jenkins commits the new image tag into `deploy/helm/pacemoney/values.yaml` and pushes to `main`. ArgoCD detects the change and rolls out the new image.

A Guard stage at the top of the Jenkinsfile detects image-tag commits (author `jenkins@kloudways.com`) and skips the pipeline, preventing an infinite trigger loop.

## Consequences

- Jenkins requires a `github-token` credential (Username+Password with a PAT having `repo` scope) to push image-tag commits
- ArgoCD's automated sync means the cluster is continuously reconciled — manual changes to the namespace will be reverted by ArgoCD's `selfHeal` policy
- A new Jenkins credential `github-token` must be added; the old `db-url` credential is retired
- The Helm Deploy stage and its `db-url` credential binding are removed from the Jenkinsfile
- Guard-stage builds (triggered by image-tag commits) appear as `[gitops]` in Jenkins build history with SUCCESS status
