---
title: Set EC2 IMDS hop limit to 2 on worker nodes
date: 2026-07-19
status: accepted
---

## Context

ESO retrieves AWS credentials via the EC2 instance metadata service (IMDS). The default IMDSv2 hop limit is 1, which allows the host process on the node to reach IMDS but prevents containers running inside pods from doing so — the extra network hop through the pod network namespace exceeds the TTL.

When ESO attempted to fetch credentials on a fresh cluster, the SecretStore status was `InvalidProviderConfig` with the event: `no EC2 IMDS role found, operation error ec2imds: GetMetadata, canceled, context deadline exceeded`.

## Decision

Set the IMDSv2 `HttpPutResponseHopLimit` to 2 on all worker nodes immediately after `kops update cluster --yes`:

```bash
for id in $(aws ec2 describe-instances --region eu-west-2 \
  --filters "Name=tag:Name,Values=nodes-*pacemoney.k8s.local" \
            "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].InstanceId" --output text); do
  aws ec2 modify-instance-metadata-options \
    --instance-id $id \
    --http-put-response-hop-limit 2 \
    --http-tokens required \
    --region eu-west-2
done
```

This takes effect immediately with no node restart required.

## Alternatives considered

**IRSA (IAM Roles for Service Accounts)** — the production-grade solution; requires enabling the OIDC provider on the kops cluster and annotating the ESO service account. Adds meaningful complexity for a lab environment.

**Static IAM credentials in a Kubernetes Secret** — simple but introduces a long-lived credential that must be rotated manually. Contradicts the purpose of using ESO.

## Consequences

The hop limit change applies to all containers on the node, not just ESO. Any container that attempts to access IMDS will now succeed, which is the desired behaviour in a trusted cluster environment.

The change is not persistent across cluster rebuilds — kops recreates the instances each time. The runbook must include this step.
