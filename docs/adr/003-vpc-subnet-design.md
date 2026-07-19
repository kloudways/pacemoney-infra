# ADR 003: Single VPC with three-tier subnet design

**Date:** 2026-07
**Status:** Accepted

## Context

The project needs network isolation between the internet-facing load balancer layer, the Kubernetes compute layer, and the database layer.

## Decision

Use a single VPC (10.1.0.0/16) with three subnet tiers across three Availability Zones (AZs):

- **Public** (10.1.1.0/24 - 10.1.3.0/24): resources with direct internet routes. Hosts the Jenkins EIP and the NAT gateway.
- **Private** (10.1.11.0/24 - 10.1.13.0/24): resources with egress-only internet access via the NAT gateway. Hosts kops Kubernetes nodes.
- **Isolated** (10.1.21.0/24 - 10.1.23.0/24): resources with no internet route at all. Hosts RDS.

Subnet CIDRs are derived via `cidrsubnet(var.vpc_cidr, 8, N)`, giving /24 blocks with a gap between tiers for future expansion.

## Consequences

- RDS is not reachable from the internet under any circumstances, only from within the VPC.
- Kubernetes nodes can reach the internet (for ECR pulls, S3, package installs) but are not directly reachable from it.
- The three-AZ spread for each tier provides resilience, though this project uses a single-master control plane.
- The VPC CIDR 10.1.0.0/16 allows up to 256 /24 subnets, leaving ample room for additional tiers (for example, a separate subnet for monitoring or a transit gateway attachment).
- An S3 gateway VPC endpoint is attached to all three route tables, routing S3 traffic within the AWS network instead of via the internet or NAT gateway.
