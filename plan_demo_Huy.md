# Plan demo Huy - Kich ban 2 va Kich ban 3

Pham vi Huy quan ly:

- Kich ban 2: KEDA autoscaling theo request rate tu Prometheus.
- Kich ban 3: security detection production stack va Argo Rollouts abort/rollback.

## 0. Mo shell GKE dung image co san

Chay tu root repo tren PowerShell:

```powershell
$repo=(Get-Location).Path
$kube=Join-Path $env:USERPROFILE ".kube"
$gcloud=Join-Path $env:APPDATA "gcloud"
docker run --rm -it `
  -v "${repo}:/workspace" `
  -v "${kube}:/root/.kube" `
  -v "${gcloud}:/root/.config/gcloud" `
  -w /workspace `
  nt548-gcloud-helm bash
```

Trong container:

```bash
gcloud config set project nt548-project
gcloud container clusters get-credentials devsecops-gke --zone us-central1-a --project nt548-project
kubectl cluster-info
kubectl get nodes -L pool
```

URL can mo san:

- App: `https://app.vuongdevops.io.vn`
- Grafana: `https://grafana.vuongdevops.io.vn` - `admin/admin`
- ArgoCD: `https://argocd.vuongdevops.io.vn` - `admin/admin`
- Argo Rollouts: `https://argorollouts.vuongdevops.io.vn`
- Jaeger: `https://jaeger.vuongdevops.io.vn`
- DefectDojo: `https://defectdojo.vuongdevops.io.vn` - `admin/admin`
- SonarQube: `https://sonarqube.vuongdevops.io.vn` - `admin/admin`
- Harbor: `https://harbor.vuongdevops.io.vn` - `admin/admin`
- Jenkins: `https://jenkins.vuongdevops.io.vn` - `admin/admin`

## 1. Deploy lai stack cho 2 kich ban

Chay trong container `nt548-gcloud-helm` tai `/workspace`:

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo add kedacore https://kedacore.github.io/charts
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo add defectdojo https://raw.githubusercontent.com/DefectDojo/django-DefectDojo/helm-charts
helm repo update

helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  -n app --create-namespace --version 4.15.1 \
  -f helm-chart/ingress-nginx/values.yaml \
  --wait --timeout 10m

helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace --version 85.2.0 \
  -f helm-chart/observation/prometheus-stack/values.yaml \
  --wait --timeout 15m

kubectl apply -f helm-chart/observation/prometheus-stack/rules/nt548-alerts.yaml
kubectl apply -f helm-chart/observation/prometheus-stack/rules/nt548-scenario3-security-alerts.yaml
kubectl apply -f helm-chart/observation/prometheus-stack/monitors/
kubectl apply -f helm-chart/observation/prometheus-stack/dashboards/scenario2-keda-dashboard-configmap.yaml

helm upgrade --install loki grafana/loki -n logging --create-namespace --version 7.0.0 -f helm-chart/observation/loki/values.yaml --wait --timeout 10m
helm upgrade --install jaeger jaegertracing/jaeger -n tracing --create-namespace --version 4.8.0 -f helm-chart/observation/jaeger/values.yaml --wait --timeout 10m
helm upgrade --install promtail grafana/promtail -n logging --version 6.17.1 -f helm-chart/observation/promtail/values.yaml --wait --timeout 10m
helm upgrade --install otel-gateway open-telemetry/opentelemetry-collector -n monitoring --version 0.156.0 -f helm-chart/observation/otel-gateway/values.yaml --wait --timeout 10m
helm upgrade --install otel-agent open-telemetry/opentelemetry-collector -n monitoring --version 0.156.0 -f helm-chart/observation/otel-agent/values.yaml --wait --timeout 10m

helm upgrade --install keda kedacore/keda -n keda --create-namespace --version 2.19.0 -f helm-chart/keda/values.yaml --wait --timeout 10m
kubectl apply -f helm-chart/keda/scaledobjects/frontend-rps-scaledobject.yaml

helm upgrade --install kyverno kyverno/kyverno -n kyverno --create-namespace --version 3.8.1 -f helm-chart/security/kyverno-values.yaml --wait --timeout 10m
helm upgrade --install falco falcosecurity/falco -n security --create-namespace --version 8.0.5 -f helm-chart/security/falco-values.yaml --wait --timeout 10m
helm upgrade --install defectdojo defectdojo/defectdojo -n defectdojo --create-namespace --version 1.9.28 -f helm-chart/defectdojo/values.yaml --wait --timeout 15m
kubectl apply -f k8s-manifest/security/scenario3-production.yaml
```

App Online Boutique do Jenkins build/push image vao Harbor, ArgoCD sync tu branch `main`.

```bash
kubectl get application online-boutique -n argocd
kubectl get rollout frontend -n app
```

Neu SonarQube bi doi password sau buoi demo truoc:

```bash
bash demo-scripts/reset-sonarqube-admin.sh
```

## 2. Kich ban 2 - KEDA autoscaling

Noi voi giang vien:

"Em dung Prometheus scrape metric request tu ingress-nginx. KEDA doc Prometheus query request/second cua ingress app. Khi RPS vuot threshold 20, KEDA tao HPA `frontend-rps-keda-hpa` de scale Argo Rollout `frontend` tu min 2 len toi da 6 replicas. ArgoCD van quan ly Rollout, KEDA chi scale qua scale subresource. Khi het tai, cooldown dua frontend ve min replicas."

Terminal 1 trong container:

```bash
bash demo-scripts/scenario2-watch.sh
```

Terminal 2 tren PowerShell host:

```powershell
$repo=(Get-Location).Path
docker run --rm -v "${repo}:/scripts" grafana/k6 run /scripts/demo-scripts/scenario2-k6.js
```

Diem can chi:

- Truoc load: HPA `frontend-rps-keda-hpa` target gan `0/20`, frontend co it nhat 2 replicas.
- Khi load tang: ScaledObject `frontend-rps-scaler` Active=True, desired replicas tang.
- Pod frontend tang len 4+.
- Sau khi load dung: target ve 0 va replicas scale down ve 2.

PromQL de mo tren Grafana/Prometheus:

```promql
sum(rate(nginx_ingress_controller_requests{namespace="app", ingress="app"}[1m]))
ALERTS{alertname="HighRequestRate"}
kube_horizontalpodautoscaler_status_current_replicas{namespace="app", horizontalpodautoscaler="frontend-rps-keda-hpa"}
```

Bang chung nen chup:

```bash
kubectl get scaledobject frontend-rps-scaler -n app
kubectl get hpa frontend-rps-keda-hpa -n app
kubectl get rollout frontend -n app
kubectl get pods -n app -l app=frontend -o wide
```

## 3. Kich ban 3 - Security detection production va rollback/abort

Noi voi giang vien:

"Kich ban 3 khong chi la script demo. Moi truong production co Falco/Falcosidekick de bat runtime threat, Kyverno de audit baseline policy, NetworkPolicy quarantine de co co che isolate pod, DefectDojo de quan ly finding, Jenkins co DAST ZAP gate, va Argo Rollouts co security analysis gate truoc khi promote frontend."

### 3.1. Preflight production

```bash
bash demo-scripts/scenario3-security-sim.sh status
kubectl get pods -n security -o wide
kubectl get pods -n kyverno -o wide
kubectl get pods -n defectdojo -o wide
kubectl get clusterpolicy nt548-scenario3-workload-baseline
kubectl get networkpolicy scenario3-quarantine -n app
kubectl get servicemonitor -A | grep -Ei 'falco|keda|ingress'
kubectl get prometheusrule nt548-scenario3-security-alerts -n monitoring
kubectl get analysistemplate frontend-security-gate -n app
```

### 3.2. Hardcoded secret detection

Chay tren PowerShell host:

```powershell
$repo=(Get-Location).Path
New-Item -ItemType Directory -Force -Path "demo-scripts/output/scenario3" | Out-Null
Set-Content -Path "app_src/frontend/scenario3_demo_leak.txt" -Value @(
  "# Scenario 3 fake leak",
  "NT548_TOKEN=`"$("demo-leak-" + "1234567890")`""
) -Encoding UTF8
docker run --rm -v "${repo}:/repo" -w /repo zricethezav/gitleaks:v8.18.2 detect --no-git --source ./app_src --config .gitleaks.toml --verbose --report-format json --report-path demo-scripts/output/scenario3/gitleaks-report.json
Remove-Item -Force "app_src/frontend/scenario3_demo_leak.txt"
```

Ket qua dung: Gitleaks bao `leaks found: 1`.

### 3.3. Vulnerable image detection

```powershell
$repo=(Get-Location).Path
New-Item -ItemType Directory -Force -Path "demo-scripts/output/scenario3" | Out-Null
docker run --rm -v "${repo}:/work" -w /work aquasec/trivy:0.50.1 image --cache-dir demo-scripts/output/scenario3/.trivy-cache --scanners vuln --format json --output demo-scripts/output/scenario3/trivy-vulnerable-image-report.json --exit-code 1 --severity HIGH,CRITICAL --ignore-unfixed nginx:1.16
```

Ket qua dung: Trivy tra exit code `1` va sinh report JSON.

### 3.4. Runtime signal, alert va quarantine

```bash
bash demo-scripts/scenario3-security-sim.sh production
bash demo-scripts/scenario3-security-sim.sh alert-rule
bash demo-scripts/scenario3-security-sim.sh runtime
kubectl logs -n security -l app.kubernetes.io/name=falco --tail=80
bash demo-scripts/scenario3-security-sim.sh isolate
kubectl get pod scenario3-runtime-threat -n app --show-labels
```

PromQL:

```promql
sum(increase(falcosidekick_falco_events_total[5m])) by (rule, priority)
sum(increase(falcosecurity_falcosidekick_falco_events_total[5m])) by (rule, priority)
sum(increase(falco_events_total[5m])) by (rule, priority)
ALERTS{scenario="security-scenario-3"}
```

### 3.5. Argo Rollouts abort/rollback

```bash
bash demo-scripts/scenario3-security-sim.sh rollout
kubectl get rollout scenario3-security-demo -n app
kubectl get analysisrun -n app | grep scenario3
```

Diem can chi:

- Stable version ban dau dung image `argoproj/rollouts-demo:blue`.
- Script patch sang `argoproj/rollouts-demo:red` de mo phong risky revision.
- AnalysisTemplate `scenario3-security-gate` fail co chu dich.
- AnalysisRun chuyen `Failed`, Rollout khong promote risky revision.
- Frontend production chart co `frontend-security-gate` de doc metric Falco/Falcosidekick tu Prometheus.

Cleanup demo resources, giu lai production policy/rule:

```bash
bash demo-scripts/scenario3-security-sim.sh cleanup
```

## 4. Cau noi demo ngan gon

Kich ban 2:

"Traffic tang lam metric ingress RPS tang. KEDA doc metric Prometheus va scale Argo Rollout frontend. Grafana hien replica/RPS/alert. Khi dung load, KEDA scale down ve min."

Kich ban 3:

"Security duoc chan o ca CI, runtime va CD. Gitleaks/Trivy/ZAP chan finding trong pipeline, Falco/Falcosidekick tao metric runtime, Kyverno audit baseline, NetworkPolicy quarantine pod bi anh huong, va Argo Rollouts abort canary khi security gate fail."
