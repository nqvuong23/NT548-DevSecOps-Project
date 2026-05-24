# Scenario 3 Expected Results

Capture these artifacts for the report/demo:

- Output of `bash demo-scripts/scenario3-security-sim.sh status`.
- Gitleaks report at `demo-scripts/output/scenario3/gitleaks-report.json`.
- Trivy report at `demo-scripts/output/scenario3/trivy-vulnerable-image-report.json`.
- Falco logs or Grafana panel showing a runtime security event.
- Prometheus or Alertmanager view showing `SecurityEventCritical` or `Scenario3RolloutSecurityGateFailed`.
- `kubectl get clusterpolicy nt548-scenario3-workload-baseline`.
- `kubectl get networkpolicy scenario3-quarantine -n app`.
- `kubectl argo rollouts get rollout scenario3-security-demo -n app`.
- `kubectl get analysisrun -n app`.

Expected behavior:

- Secret scan: Gitleaks exits with finding status because a temporary fake `NT548_TOKEN` is created under `app_src`, then removed.
- Image scan: Trivy finds HIGH/CRITICAL vulnerabilities in the intentionally old image.
- Runtime signal: Falco detects shell/sensitive-file behavior and Falcosidekick exposes metrics to Prometheus.
- Quarantine signal: labeling the runtime pod with `security.nt548/quarantine=true` activates the persistent `scenario3-quarantine` NetworkPolicy.
- Rollout signal: the canary update to `argoproj/rollouts-demo:red` starts, the `scenario3-security-gate` AnalysisTemplate fails, and Argo Rollouts aborts the risky revision.
- Cleanup: `scenario3-runtime-threat` and `scenario3-security-demo` are removed; the Scenario 3 PrometheusRule, Kyverno policy, and quarantine NetworkPolicy remain loaded for future demos.
