# Scenario 2 Checklist - KEDA Autoscaling

## Preconditions

- Prometheus stack is running in `monitoring`.
- `ingress-nginx-controller` target is `UP` in Prometheus.
- `otel-gateway` target is `UP` in Prometheus.
- `HighRequestRate` rule is loaded.
- KEDA is installed in `keda`.
- `frontend-rps-scaler` exists in `app`.
- Argo Rollout `frontend` is at or near 2 replicas before load starts.

## Demo Flow

1. Open Grafana at `https://grafana.vuongdevops.io.vn`.
2. Open the `NT548 KEDA Scenario 2` dashboard.
3. Open Prometheus alerts or Alertmanager.
4. Start the watcher:

   ```bash
   bash demo-scripts/scenario2-watch.sh
   ```

5. Run the load test:

   ```bash
   k6 run demo-scripts/scenario2-k6.js
   ```

6. Observe request rate crossing the KEDA threshold.
7. Observe `HighRequestRate` moving to `FIRING`.
8. Observe KEDA-created HPA desired replicas increasing.
9. Observe frontend rollout pods scaling from 2 toward 6.
10. Let the k6 test finish.
11. Observe request rate dropping.
12. Observe the alert resolving.
13. Observe frontend rollout replicas scaling down after cooldown.

## Query To Validate Before Demo

```promql
sum(rate(nginx_ingress_controller_requests{namespace="app", ingress="app"}[1m]))
```

If this query returns no series, inspect the raw metric labels:

```promql
nginx_ingress_controller_requests
```

Then update the ScaledObject and alert rule to match the live labels.
