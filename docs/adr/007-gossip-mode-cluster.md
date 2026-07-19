# ADR 007: kops gossip DNS mode

**Date:** 2026-07
**Status:** Accepted

## Context

kops requires a DNS mechanism for cluster nodes to discover each other. The two options are:

- **Route 53 hosted zone**: kops manages DNS records in a dedicated hosted zone (for example, `k8s.kloudways.com`). Requires delegating a subdomain to Route 53.
- **Gossip mode**: the cluster name ends in `.k8s.local`. kops uses a gossip protocol for internal DNS. No external DNS zone is required.

## Decision

Use gossip mode: `cluster_name = "pacemoney.k8s.local"`.

## Consequences

- No Route 53 hosted zone is required for the cluster. The existing `kloudways.com` zone is used only for application and Jenkins hostnames, not for cluster-internal DNS.
- The cluster is not externally resolvable by name, which is appropriate for a private-topology cluster.
- The kops API server is reachable via the NLB (Network Load Balancer) that kops provisions for the control plane. `kops export kubecfg` writes this endpoint to the local kubeconfig.
- If the project is extended to use external-dns or cert-manager with Route 53, a real hosted zone would need to be introduced.
