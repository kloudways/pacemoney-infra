# ADR 002: AWS region eu-west-2

**Date:** 2026-07
**Status:** Accepted

## Context

A single AWS region must be chosen for all resources. The project has no multi-region or latency requirements.

## Decision

Use eu-west-2 (London).

## Consequences

- All resources (VPC, EC2, RDS, ECR, S3, Route 53 record targets) are in eu-west-2.
- The Terraform backend bucket (`kloudways-pacemoney-tfstate`) is also in eu-west-2.
- Data transfer between resources within the same region is free.
- If the project is extended to multi-region in the future, the VPC CIDR and resource naming conventions will need to account for the region.
