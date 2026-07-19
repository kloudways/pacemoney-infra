---
title: Deploy monitoring via kube-prometheus-stack Helm chart
date: 2026-07-19
status: accepted
---

## Context

Phase 6 requires Prometheus metrics collection and Grafana dashboards. The app exposes `/metrics` via `prometheus-fastapi-instrumentator`. Prometheus needs to be told where to scrape it.

## Decision

Deploy `prometheus-community/kube-prometheus-stack` into a dedicated `monitoring` namespace. This single chart installs Prometheus, Grafana, AlertManager, and the Prometheus Operator (which provides the `ServiceMonitor` CRD used by the app's Helm chart). Grafana is exposed via a `LoadBalancer` service for browser access.

## Consequences

- The `ServiceMonitor` CRD must exist before the app's Helm chart can be installed; the monitoring stack must be deployed first on a fresh cluster
- Grafana gets a new ELB hostname on every cluster recreate (no DNS record managed for it)
- Helm API discovery cache on Jenkins must be cleared after the monitoring stack is installed so Jenkins can find the `ServiceMonitor` CRD
