# Observation stack

This directory contains Helm values for Task 4.2:

- Loki receives logs.
- Jaeger receives traces.
- `otel-agent` runs as a DaemonSet on `app-pool`.
- `otel-gateway` runs as a Deployment on `observation-pool`.

Terraform currently labels `observation-pool` with `pool=observation` and does not define a taint for it in `terraform/modules/gke/main.tf`. These values therefore use node affinity for observation workloads and no observation toleration. If the pool is tainted later, add the matching toleration to Loki, Jaeger, and `otel-gateway`.

Loki is configured for lab/demo use with filesystem storage on an `emptyDir` mounted at `/var/loki`. Logs are not persistent across Loki pod deletion. Switch `singleBinary.persistence.enabled` to a PVC-backed setup for longer-lived environments.

## Helm repositories

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update
```

## Install order

```bash
helm upgrade --install loki grafana/loki \
  -n logging \
  --create-namespace \
  -f helm-chart/observation/loki/values.yaml

helm upgrade --install jaeger jaegertracing/jaeger \
  -n tracing \
  --create-namespace \
  -f helm-chart/observation/jaeger/values.yaml

helm upgrade --install otel-gateway open-telemetry/opentelemetry-collector \
  -n monitoring \
  --create-namespace \
  -f helm-chart/observation/otel-gateway/values.yaml

helm upgrade --install otel-agent open-telemetry/opentelemetry-collector \
  -n monitoring \
  -f helm-chart/observation/otel-agent/values.yaml
```

Then deploy the app chart:

```bash
helm upgrade --install onlineboutique helm-chart/microservices \
  -n app \
  --create-namespace
```

## Data flow

Application services that already read `COLLECTOR_SERVICE_ADDR` render it as `$(NODE_IP):4317`. Kubernetes expands `NODE_IP` from `status.hostIP`, so traces go to the local `otel-agent` hostPort on the same app node.

`otel-agent` forwards logs, traces, and metrics to `otel-gateway`.

`otel-gateway` forwards:

- traces to `jaeger.tracing.svc.cluster.local:4317`
- logs to `http://loki-gateway.logging.svc.cluster.local/otlp`
- metrics to a Prometheus scrape endpoint exposed on `otel-gateway:8889`

## Verify

```bash
kubectl get pods -n app -o wide
kubectl get pods -n logging -o wide
kubectl get pods -n tracing -o wide
kubectl get pods -n monitoring -o wide

kubectl get svc -n logging
kubectl get svc -n tracing
kubectl get svc -n monitoring

kubectl logs -n monitoring deploy/otel-gateway
kubectl logs -n monitoring ds/otel-agent-agent
```

Expected scheduling:

- Online Boutique pods: nodes with `pool=app`
- `otel-agent-agent` DaemonSet: nodes with `pool=app`
- Loki, Jaeger, `otel-gateway`: nodes with `pool=observation`

## Grafana datasources

Use these service URLs:

- Loki: `http://loki-gateway.logging.svc.cluster.local`
- Jaeger: `http://jaeger.tracing.svc.cluster.local:16686`

Log-to-trace correlation depends on application logs containing a trace ID. Some services in this repo log JSON, but not all services inject trace IDs into logs. Do not mark log-to-trace correlation complete until a real log line with trace ID is verified.
