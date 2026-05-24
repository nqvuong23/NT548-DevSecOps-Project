# Scenario 3 Expected Results

Capture these artifacts for the report/demo:

- Output of `bash demo-scripts/scenario3-security-sim.sh status`.
- Gitleaks report at `demo-scripts/output/scenario3/gitleaks-report.json`.
- Trivy report at `demo-scripts/output/scenario3/trivy-vulnerable-image-report.json`.
- Falco logs or Grafana panel showing a runtime security event, if Falco is installed.
- Prometheus or Alertmanager view showing `SecurityEventCritical` or `Scenario3RolloutSecurityGateFailed`.
- `kubectl argo rollouts get rollout scenario3-security-demo -n app`.
- `kubectl get analysisrun -n app`.
- Optional `kubectl get networkpolicy scenario3-isolate-runtime-threat -n app`.

Expected behavior:

- Secret scan: Gitleaks exits with finding status because a temporary fake `NT548_TOKEN` is created under `app_src`, then removed.
- Image scan: Trivy finds HIGH/CRITICAL vulnerabilities in the intentionally old image.
- Runtime signal: Falco detects shell/sensitive-file behavior when Falco is deployed.
- Rollout signal: the canary update to `argoproj/rollouts-demo:red` starts, the `scenario3-security-gate` AnalysisTemplate fails, and Argo Rollouts aborts the risky revision.
- Cleanup: `scenario3-runtime-threat`, `scenario3-security-demo`, and `scenario3-isolate-runtime-threat` are removed; the Scenario 3 PrometheusRule remains loaded for future demos.
