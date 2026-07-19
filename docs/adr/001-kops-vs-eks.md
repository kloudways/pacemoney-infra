# ADR 001: kops over EKS

**Date:** 2026-07
**Status:** Accepted

## Context

The project requires a Kubernetes cluster to run the application. Two viable options for AWS are kops (Kubernetes Operations) on self-managed EC2 and Amazon Elastic Kubernetes Service (EKS).

EKS is the standard production choice: AWS manages the control plane, upgrade paths are well-defined, and integration with AWS services (IAM Roles for Service Accounts, ELB controller, etc.) is first-class.

kops provisions and manages both the control plane and worker nodes on EC2. It exposes more configuration surface and requires the operator to understand what kops is doing at each layer (etcd, kubelet bootstrap, network plugin selection, IAM role construction).

## Decision

Use kops on EC2.

## Consequences

- The control plane (etcd, API server, controller manager, scheduler) runs on an EC2 instance managed by the operator, not by AWS.
- kops creates and manages its own IAM roles, security groups, launch templates, and auto scaling groups. These are not tracked in the project's Terraform state.
- Upgrading Kubernetes requires a kops rolling update, not an EKS console click.
- The operator gains direct experience with cluster internals, which is the primary goal of this project.
- EKS-specific features (EKS Pod Identity, EKS-managed node groups) are not available.
- Teardown requires `kops delete cluster` before `terraform destroy`, because kops resources live outside the Terraform state.
