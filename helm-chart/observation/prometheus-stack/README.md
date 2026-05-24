# Prometheus, Grafana, and Alerting

This folder represents Task 4.1 with `kube-prometheus-stack`.

Pinned chart:

- `prometheus-community/kube-prometheus-stack` version `85.2.0`

The stack installs Prometheus Operator, Prometheus, Alertmanager, Grafana, kube-state-metrics, and node-exporter. Prometheus and Grafana are scheduled to `observation-pool`. Node exporter intentionally runs on every node and tolerates the tainted `app-pool`.

## Install

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring \
  --create-namespace \
  --version 85.2.0 \
  -f helm-chart/observation/prometheus-stack/values.yaml \
  --wait \
  --timeout 15m

kubectl apply -f helm-chart/observation/prometheus-stack/rules/nt548-alerts.yaml
kubectl apply -f helm-chart/observation/prometheus-stack/rules/nt548-scenario3-security-alerts.yaml
kubectl apply -f helm-chart/observation/prometheus-stack/monitors/
kubectl apply -f helm-chart/observation/prometheus-stack/dashboards/scenario2-keda-dashboard-configmap.yaml
```

If ingress-nginx was already installed by Terraform, refresh that Helm release so the updated metrics settings in `helm-chart/ingress-nginx/values.yaml` are active:

```bash
helm upgrade ingress-nginx ingress-nginx/ingress-nginx \
  -n app \
  --reuse-values \
  -f helm-chart/ingress-nginx/values.yaml \
  --wait \
  --timeout 10m
```

## Prometheus Discovery

The values set these selectors to discover monitors and rules created outside the Helm release:

- `ruleSelectorNilUsesHelmValues: false`
- `serviceMonitorSelectorNilUsesHelmValues: false`
- `podMonitorSelectorNilUsesHelmValues: false`

## Scenario 2 Queries

Request rate for KEDA and alerting:

```promql
sum(rate(nginx_ingress_controller_requests{namespace="app", ingress="app"}[1m]))
```

KEDA current frontend rollout replicas:

```promql
kube_horizontalpodautoscaler_status_current_replicas{namespace="app", horizontalpodautoscaler="frontend-rps-keda-hpa"}
```

HighRequestRate alert state:

```promql
ALERTS{alertname="HighRequestRate", alertstate="firing"}
```

## Scenario 3 Queries

Falco runtime security events, when Falco/Falcosidekick is installed:

```promql
sum(increase(falco_events_total[5m])) by (rule, priority)
```

Scenario 3 alert states:

```promql
ALERTS{scenario="security-scenario-3"}
```

## Verify

```bash
kubectl get pods -n monitoring -o wide
kubectl get prometheus -A
kubectl get alertmanager -A
kubectl get prometheusrules -A
kubectl get servicemonitors -A
```

Expected targets:

- `ingress-nginx-controller` ServiceMonitor is `UP`.
- `otel-gateway` ServiceMonitor is `UP`.
- `nt548-scenario2-alerts` rules are loaded.
- `nt548-scenario3-security-alerts` rules are loaded for the security demo.
- Grafana has Prometheus, Loki, and Jaeger datasources.
