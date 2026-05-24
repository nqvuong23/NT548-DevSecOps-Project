# Scenario 2 Expected Results

Capture these artifacts for the report/demo:

- `kubectl get scaledobjects -A`
- `kubectl describe scaledobject frontend-rps-scaler -n app`
- `kubectl get hpa -n app`
- `kubectl get rollout frontend -n app`
- `kubectl get pods -n app -l app=frontend,rollouts-pod-template-hash -o wide`
- Grafana panel showing ingress request rate increasing.
- Grafana panel showing frontend replicas increasing.
- Prometheus or Alertmanager view showing `HighRequestRate` as `FIRING`.
- Later screenshot showing `HighRequestRate` resolved.
- Later `kubectl get hpa -n app` showing desired replicas back near 2.

Expected behavior:

- Before load: Argo Rollout `frontend` runs at 2 replicas after KEDA reconciles.
- During load: ingress request rate exceeds the configured threshold of `20`.
- During load: `frontend-rps-keda-hpa` increases desired replicas toward 6 for Rollout `frontend`.
- After load: replicas scale down after the 120 second KEDA cooldown and HPA scale-down behavior.
