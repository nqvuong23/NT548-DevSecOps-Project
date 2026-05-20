# Observation Stack

This directory contains the observability implementation for Tasks 4.1 and 4.2:

- `prometheus-stack`: Prometheus Operator, Prometheus, Alertmanager, Grafana, rules, monitors, and dashboards.
- `loki`: Loki single-binary lab deployment.
- `promtail`: container log shipping from `app-pool` pods to Loki.
- `jaeger`: Jaeger v2 all-in-one lab deployment.
- `otel-agent`: OpenTelemetry Collector DaemonSet on `app-pool`.
- `otel-gateway`: OpenTelemetry Collector Deployment on `observation-pool`.

Terraform currently labels `observation-pool` with `pool=observation` and does not define a taint for it in `terraform/modules/gke/main.tf`. These values therefore use required node affinity for observation workloads and no observation toleration. If the pool is tainted later, add the matching toleration to Loki, Jaeger, Prometheus stack, Grafana, and `otel-gateway`.

## Pinned Chart Versions

| Component | Chart | Version |
|---|---|---:|
| Prometheus stack | `prometheus-community/kube-prometheus-stack` | `85.2.0` |
| Loki | `grafana/loki` | `7.0.0` |
| Promtail | `grafana/promtail` | `6.17.1` |
| Jaeger | `jaegertracing/jaeger` | `4.8.0` |
| OpenTelemetry Collector | `open-telemetry/opentelemetry-collector` | `0.156.0` |

The standalone `grafana/values.yaml` file is retained for reference/backward compatibility. The recommended demo Grafana is the Grafana instance installed by `kube-prometheus-stack`.

## Helm Repositories

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update
```

## Install Order

Install Prometheus stack first so the Prometheus Operator CRDs exist before applying ServiceMonitors and PrometheusRules:

```bash
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring \
  --create-namespace \
  --version 85.2.0 \
  -f helm-chart/observation/prometheus-stack/values.yaml \
  --wait \
  --timeout 15m

kubectl apply -f helm-chart/observation/prometheus-stack/rules/nt548-alerts.yaml
kubectl apply -f helm-chart/observation/prometheus-stack/monitors/
kubectl apply -f helm-chart/observation/prometheus-stack/dashboards/scenario2-keda-dashboard-configmap.yaml
```

Install logs, traces, and collectors:

```bash
helm upgrade --install loki grafana/loki \
  -n logging \
  --create-namespace \
  --version 7.0.0 \
  -f helm-chart/observation/loki/values.yaml \
  --wait \
  --timeout 10m

helm upgrade --install jaeger jaegertracing/jaeger \
  -n tracing \
  --create-namespace \
  --version 4.8.0 \
  -f helm-chart/observation/jaeger/values.yaml \
  --wait \
  --timeout 10m

helm upgrade --install promtail grafana/promtail \
  -n logging \
  --version 6.17.1 \
  -f helm-chart/observation/promtail/values.yaml \
  --wait \
  --timeout 10m

helm upgrade --install otel-gateway open-telemetry/opentelemetry-collector \
  -n monitoring \
  --create-namespace \
  --version 0.156.0 \
  -f helm-chart/observation/otel-gateway/values.yaml \
  --wait \
  --timeout 10m

helm upgrade --install otel-agent open-telemetry/opentelemetry-collector \
  -n monitoring \
  --version 0.156.0 \
  -f helm-chart/observation/otel-agent/values.yaml \
  --wait \
  --timeout 10m
```

Then deploy the app chart:

```bash
helm upgrade --install onlineboutique helm-chart/microservices \
  -n app \
  --create-namespace
```

## Data Flow

Application services that read `COLLECTOR_SERVICE_ADDR` render it as `$(NODE_IP):4317`. Kubernetes expands `NODE_IP` from `status.hostIP`, so traces go to the local `otel-agent` hostPort on the same app node.

Current log path:

- Promtail tails container logs from namespace `app` on `app-pool`.
- Promtail sends logs to `http://loki-gateway.logging.svc.cluster.local/loki/api/v1/push`.

Current trace and metric path:

- `otel-agent` receives OTLP gRPC/HTTP on app nodes.
- `otel-agent` forwards traces, metrics, and any OTLP logs to `otel-gateway`.
- `otel-gateway` forwards traces to `jaeger.tracing.svc.cluster.local:4317`.
- `otel-gateway` forwards OTLP logs to `http://loki-gateway.logging.svc.cluster.local/otlp`.
- `otel-gateway` exposes metrics on `:8889` for Prometheus scraping.

`otel-agent.presets.logsCollection.enabled` is intentionally `false` because Promtail is the primary container stdout log shipper. This avoids duplicate Loki ingestion.

Loki and Jaeger are lab/demo configurations. Loki uses filesystem storage on `emptyDir`; Jaeger uses ephemeral in-memory storage. Data is not retained after pod deletion.

## Verify

```bash
kubectl get pods -n app -o wide
kubectl get pods -n logging -o wide
kubectl get pods -n tracing -o wide
kubectl get pods -n monitoring -o wide

kubectl get svc -n logging
kubectl get svc -n tracing
kubectl get svc -n monitoring

kubectl get servicemonitors -A
kubectl get prometheusrules -A

kubectl logs -n monitoring deploy/otel-gateway
kubectl logs -n monitoring ds/otel-agent-agent
kubectl logs -n logging ds/promtail
```

Expected scheduling:

- Online Boutique pods: nodes with `pool=app`
- `otel-agent-agent` DaemonSet: nodes with `pool=app`
- Promtail DaemonSet: nodes with `pool=app`
- Loki, Jaeger, Prometheus, Alertmanager, Grafana, `otel-gateway`: nodes with `pool=observation`
- Node exporter: all nodes

## Grafana Datasources

Grafana is exposed at `http://grafana.vuongdevops.io.vn` through the `kube-prometheus-stack` Grafana instance and is provisioned with:

- Prometheus: in-cluster `kube-prometheus-stack-prometheus` service
- Loki: `http://loki-gateway.logging.svc.cluster.local`
- Jaeger: `http://jaeger.tracing.svc.cluster.local:16686`

Log-to-trace correlation depends on application logs containing a trace ID. Do not mark correlation complete until a real log line with `traceID`, `trace_id`, or `traceid` is verified and links to a Jaeger trace.
