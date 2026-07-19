# ADR 008: Kubernetes Service type LoadBalancer over ALB Ingress

**Date:** 2026-07
**Status:** Accepted

## Context

Exposing the application to the internet requires a Kubernetes ingress mechanism. Two options were considered:

- **AWS Load Balancer Controller with ALB Ingress**: one Application Load Balancer (ALB) shared across multiple Services via Ingress rules. Requires installing the controller, setting up an OIDC provider, and configuring IAM Roles for Service Accounts (IRSA).
- **Kubernetes Service `type: LoadBalancer`**: kops provisions a Classic Elastic Load Balancer (ELB) automatically for each Service of this type. No additional controllers required.

## Decision

Use `type: LoadBalancer` on the Kubernetes Service.

## Consequences

- kops provisions a Classic ELB automatically when the Service is created. No additional controller installation or IAM configuration is required.
- The ELB hostname is not known until after the first deployment. The Route 53 CNAME record for `pacemoney.kloudways.com` must be updated manually in `terraform.tfvars` after the first deploy.
- One ELB is created per LoadBalancer Service. For a single-service project this is cost-equivalent to an ALB, but at scale this approach becomes more expensive than a shared ALB.
- Classic ELBs are in maintenance mode at AWS. For a production system with multiple services, the ALB Ingress approach would be preferred.
- The `service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"` annotation in `values.yaml` is an ALB controller annotation and has no effect on the Classic ELB provisioned by kops, but it does not cause any errors.
