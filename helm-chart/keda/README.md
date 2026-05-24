# KEDA Autoscaling - Scenario 2

This folder implements README Scenario 2 for traffic-based scaling of the Online Boutique `frontend` Argo Rollout.

Pinned chart:

- `kedacore/keda` version `2.19.0`

KEDA runs on `platform-pool` using required node affinity. The platform pool is not tainted in Terraform, so no toleration is configured.

## Install

Install Prometheus first, then KEDA:

```bash
helm repo add kedacore https://kedacore.github.io/charts
helm repo update

helm upgrade --install keda kedacore/keda \
  -n keda \
  --create-namespace \
  --version 2.19.0 \
  -f helm-chart/keda/values.yaml \
  --wait \
  --timeout 10m
```

Deploy the scaler after the `frontend` Rollout and ingress-nginx metrics are available:

```bash
kubectl apply -f helm-chart/keda/scaledobjects/frontend-rps-scaledobject.yaml
```

## Trigger Metric

The ScaledObject uses ingress-nginx request rate:

```promql
sum(rate(nginx_ingress_controller_requests{namespace="app", ingress="app"}[1m]))
```

Before the final demo, validate the query in Prometheus. If the live ingress labels differ, update both:

- `helm-chart/keda/scaledobjects/frontend-rps-scaledobject.yaml`
- `helm-chart/observation/prometheus-stack/rules/nt548-alerts.yaml`

## Verify

```bash
kubectl get pods -n keda -o wide
kubectl get scaledobjects -n app
kubectl describe scaledobject frontend-rps-scaler -n app
kubectl get hpa -n app
```

Expected:

- KEDA pods run on nodes labeled `pool=platform`.
- `frontend-rps-scaler` is ready.
- KEDA creates `frontend-rps-keda-hpa` against `argoproj.io/v1alpha1 Rollout/frontend`.
- Under load, frontend rollout replicas move from 2 toward 6, then scale down after cooldown.
- The demo threshold is `20` RPS because the current GKE lab cluster reached about 50-65 RPS during k6 validation, while KEDA/HPA samples a lower one-minute value during ramp down.
