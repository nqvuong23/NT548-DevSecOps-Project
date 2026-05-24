# Scenario 3 Checklist - Security Detection and Rollback

## Preconditions

- Jenkins pipeline has Gitleaks and Trivy stages.
- Docker host is available for local Gitleaks/Trivy demo commands.
- Argo Rollouts controller is installed in `argo-rollouts`.
- `kubectl argo rollouts` plugin is installed for the cleanest demo view.
- Prometheus stack is running in `monitoring`.
- Falco, Falcosidekick, Kyverno, and DefectDojo are running.
- Grafana URL: `https://grafana.vuongdevops.io.vn` with `admin/admin`.

## Demo Flow

1. Show the README Scenario 3 goal: security signal blocks or rolls back a risky change.
2. Run the preflight:

   ```bash
   bash demo-scripts/scenario3-security-sim.sh status
   ```

3. Demonstrate hardcoded secret detection on a shell with Docker or Gitleaks:

   ```bash
   bash demo-scripts/scenario3-security-sim.sh secret
   ```

4. Demonstrate vulnerable image detection on a shell with Docker or Trivy:

   ```bash
   bash demo-scripts/scenario3-security-sim.sh image
   ```

5. Apply persistent production controls and security alert rules:

   ```bash
   bash demo-scripts/scenario3-security-sim.sh production
   bash demo-scripts/scenario3-security-sim.sh alert-rule
   ```

6. Trigger a runtime event for Falco:

   ```bash
   bash demo-scripts/scenario3-security-sim.sh runtime
   ```

7. Optional containment step:

   ```bash
   bash demo-scripts/scenario3-security-sim.sh isolate
   ```

8. Demonstrate rollout abort/rollback behavior:

   ```bash
   bash demo-scripts/scenario3-security-sim.sh rollout
   kubectl argo rollouts get rollout scenario3-security-demo -n app
   kubectl get analysisrun -n app
   ```

9. Return demo resources to a clean state:

   ```bash
   bash demo-scripts/scenario3-security-sim.sh rollback
   bash demo-scripts/scenario3-security-sim.sh cleanup
   ```

## Prometheus Queries

Falco runtime event:

```promql
sum(increase(falcosidekick_falco_events_total[5m])) by (rule, priority)
sum(increase(falcosecurity_falcosidekick_falco_events_total[5m])) by (rule, priority)
sum(increase(falco_events_total[5m])) by (rule, priority)
```

Scenario 3 security alert state:

```promql
ALERTS{scenario="security-scenario-3"}
```

Rollout analysis failure job:

```promql
kube_job_status_failed{namespace="app", job_name=~".*scenario3-security.*"}
```
