# Plan demo Huy - Kich ban 2 va Kich ban 3

Pham vi Huy quan ly:

- Kich ban 2: KEDA autoscaling theo request rate tu Prometheus.
- Kich ban 3: security detection va Argo Rollouts abort/rollback.

Tat ca lenh Kubernetes/Helm nen chay trong image Docker co san:

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

- App: `http://app.vuongdevops.io.vn`
- Grafana: `http://grafana.vuongdevops.io.vn` - login `admin/admin`
- Argo Rollouts: `http://argorollouts.vuongdevops.io.vn`
- Jaeger: `http://jaeger.vuongdevops.io.vn`

## 1. Deploy lai stack cho 2 kich ban

Chay trong container `nt548-gcloud-helm` tai `/workspace`:

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo add kedacore https://kedacore.github.io/charts
helm repo update

helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  -n app --create-namespace --version 4.15.1 \
  -f helm-chart/ingress-nginx/values.yaml \
  --wait --timeout 10m

helm template online-boutique helm-chart/microservices \
  -n app \
  -f helm-chart/microservices/values.yaml \
  -f helm-chart/microservices/values-demo-public.yaml \
  | kubectl apply -f -

kubectl rollout status deploy/frontend -n app --timeout=5m

helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace --version 85.2.0 \
  -f helm-chart/observation/prometheus-stack/values.yaml \
  --wait --timeout 15m

kubectl apply -f helm-chart/observation/prometheus-stack/rules/nt548-alerts.yaml
kubectl apply -f helm-chart/observation/prometheus-stack/rules/nt548-scenario3-security-alerts.yaml
kubectl apply -f helm-chart/observation/prometheus-stack/monitors/
kubectl apply -f helm-chart/observation/prometheus-stack/dashboards/scenario2-keda-dashboard-configmap.yaml

helm upgrade --install loki grafana/loki \
  -n logging --create-namespace --version 7.0.0 \
  -f helm-chart/observation/loki/values.yaml \
  --wait --timeout 10m

helm upgrade --install jaeger jaegertracing/jaeger \
  -n tracing --create-namespace --version 4.8.0 \
  -f helm-chart/observation/jaeger/values.yaml \
  --wait --timeout 10m

helm upgrade --install promtail grafana/promtail \
  -n logging --version 6.17.1 \
  -f helm-chart/observation/promtail/values.yaml \
  --wait --timeout 10m

helm upgrade --install otel-gateway open-telemetry/opentelemetry-collector \
  -n monitoring --version 0.156.0 \
  -f helm-chart/observation/otel-gateway/values.yaml \
  --wait --timeout 10m

helm upgrade --install otel-agent open-telemetry/opentelemetry-collector \
  -n monitoring --version 0.156.0 \
  -f helm-chart/observation/otel-agent/values.yaml \
  --wait --timeout 10m

helm upgrade --install keda kedacore/keda \
  -n keda --create-namespace --version 2.19.0 \
  -f helm-chart/keda/values.yaml \
  --wait --timeout 10m

kubectl apply -f helm-chart/keda/scaledobjects/frontend-rps-scaledobject.yaml
```

Kiem tra nhanh:

```bash
kubectl get pods -n app
kubectl get pods -n monitoring
kubectl get pods -n logging
kubectl get pods -n tracing
kubectl get pods -n keda
kubectl get scaledobject -n app
kubectl get hpa -n app
kubectl get prometheusrule -n monitoring | grep nt548
```

## 2. Kich ban 2 - KEDA autoscaling

Noi voi giang vien:

"Em dung Prometheus scrape metric request tu ingress-nginx. KEDA doc Prometheus query request/second cua ingress app. Khi RPS vuot threshold 20, KEDA tao HPA `frontend-rps-keda-hpa` de scale `frontend` tu min 2 len toi da 6 replicas. Khi het tai, cooldown 120s dua frontend ve min replicas."

### 2.1. Mo UI

- App: `http://app.vuongdevops.io.vn`
- Grafana: `http://grafana.vuongdevops.io.vn`, login `admin/admin`
- Dashboard: `NT548 KEDA Scenario 2`

### 2.2. Watch resource

Terminal 1 trong container:

```bash
bash demo-scripts/scenario2-watch.sh
```

### 2.3. Chay load test

Terminal 2 tren PowerShell host:

```powershell
$repo=(Get-Location).Path
docker run --rm -v "${repo}:/scripts" grafana/k6 run /scripts/demo-scripts/scenario2-k6.js
```

Hoac neu may co `k6`:

```bash
k6 run demo-scripts/scenario2-k6.js
```

### 2.4. Diem can chi ra

Trong terminal watch:

- Truoc load: `frontend` co 2 replicas.
- Khi load tang: HPA `frontend-rps-keda-hpa` target vuot `20`, desired replicas tang.
- Pod `frontend` tang len 4+.
- Sau khi load dung: HPA target ve 0 va replicas scale down ve 2.

Trong Grafana/Prometheus:

```promql
sum(rate(nginx_ingress_controller_requests{namespace="app", ingress="app"}[1m]))
ALERTS{alertname="HighRequestRate"}
kube_deployment_status_replicas_available{namespace="app", deployment="frontend"}
```

Bang chung nen chup:

```bash
kubectl get hpa -n app
kubectl describe scaledobject frontend-rps-scaler -n app
kubectl get pods -n app -l app=frontend,pod-template-hash -o wide
```

## 3. Kich ban 3 - Security detection va rollback/abort

Noi voi giang vien:

"Kich ban 3 gom 3 lop bao ve. Lop CI dung Gitleaks va Trivy de chan secret/image loi. Lop runtime tao signal cho Falco neu Falco duoc deploy. Lop CD dung Argo Rollouts AnalysisTemplate de abort canary khi security gate fail, giu lai revision stable."

### 3.1. Preflight

```bash
bash demo-scripts/scenario3-security-sim.sh status
kubectl get pods -n argo-rollouts
kubectl get crd rollouts.argoproj.io
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

Ket qua dung: Gitleaks bao `leaks found: 1`, report nam o `demo-scripts/output/scenario3/gitleaks-report.json`.

### 3.3. Vulnerable image detection

Chay tren PowerShell host:

```powershell
$repo=(Get-Location).Path
New-Item -ItemType Directory -Force -Path "demo-scripts/output/scenario3" | Out-Null
docker run --rm -v "${repo}:/work" -w /work aquasec/trivy:0.50.1 image --cache-dir demo-scripts/output/scenario3/.trivy-cache --scanners vuln --format json --output demo-scripts/output/scenario3/trivy-vulnerable-image-report.json --exit-code 1 --severity HIGH,CRITICAL --ignore-unfixed nginx:1.16
```

Ket qua dung: Trivy tra exit code `1` vi tim thay HIGH/CRITICAL vulnerabilities, report nam o `demo-scripts/output/scenario3/trivy-vulnerable-image-report.json`.

### 3.4. Runtime signal va alert rule

Chay trong container:

```bash
bash demo-scripts/scenario3-security-sim.sh alert-rule
bash demo-scripts/scenario3-security-sim.sh runtime
```

Query Prometheus neu Falco/Falcosidekick co metric:

```promql
sum(increase(falco_events_total[5m])) by (rule, priority)
ALERTS{scenario="security-scenario-3"}
```

Optional isolate pod:

```bash
bash demo-scripts/scenario3-security-sim.sh isolate
kubectl get networkpolicy scenario3-isolate-runtime-threat -n app
```

### 3.5. Argo Rollouts abort/rollback

Chay trong container:

```bash
bash demo-scripts/scenario3-security-sim.sh rollout
kubectl get rollout scenario3-security-demo -n app
kubectl get analysisrun -n app | grep scenario3
```

Diem can chi ra:

- Stable version ban dau dung image `argoproj/rollouts-demo:blue`.
- Script patch sang `argoproj/rollouts-demo:red` de mo phong risky revision.
- AnalysisTemplate `scenario3-security-gate` tao job fail co chu dich.
- AnalysisRun chuyen `Failed`.
- Rollout giu stable replicas va khong promote risky revision.

Cleanup sau demo:

```bash
bash demo-scripts/scenario3-security-sim.sh cleanup
```

## 4. Cau noi demo ngan gon

Kich ban 2:

"Khi traffic tang, Prometheus co metric ingress request rate. KEDA doc metric do, tao HPA va scale frontend. Alert `HighRequestRate` firing tren Grafana/Prometheus. Khi load dung, HPA scale down ve min replicas."

Kich ban 3:

"Khi co dau hieu bao mat, pipeline/security gate phai chan hoac rollback. Gitleaks bat secret hardcode, Trivy bat image co CVE, Falco co the bat runtime threat, va Argo Rollouts abort canary khi AnalysisTemplate fail."
