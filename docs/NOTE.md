## Hướng dẫn triển khai hạ tầng (Deployment Guide)

### Điều kiện tiên quyết (Prerequisites)

Đảm bảo trên laptop đã cài đặt các công cụ sau:

- **gcloud CLI**: Công cụ dòng lệnh để tương tác với Google Cloud.
- **Terraform**: Tạo và quản lý hạ tầng Google Cloud.
- **kubectl**: Thao tác và quản lý tài nguyên K8s.
- **Helm**: Trình quản lý gói cho K8s.

### Các bước thực hiện

#### **Bước 1: Đăng nhập vào Google Cloud**

```
gcloud auth application-default login
```

- Dùng lệnh trên Terminal, nó sẽ redirect sang 1 trang web trên trình duyệt, đăng nhập bằng tài khoản Google đã được thêm vào Google Cloud Project

#### **Bước 2: Chọn Project ID**

```
gcloud config set project nt548-project
```

#### **Bước 3: Kiểm tra lại cấu hình hiện tại**

```
gcloud config get-value project
```

- Đảm bảo tên project là `nt548-project`

### Một số lưu ý

- không dùng `terraform workspace` để tạo nhiều môi trường, chỉ dùng 1 môi trường duy nhất.
- Các lệnh triển khai sẽ được cập nhập thường xuyên.

---

## Các lệnh triển khai hạ tầng (Nhớ chạy theo đúng thứ tự)

```
# Add Helm Chart Repo 
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add jenkins https://charts.jenkins.io
helm repo add sonarqube https://SonarSource.github.io/helm-chart-sonarqube

helm repo add harbor https://helm.goharbor.io
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo add argo https://argoproj.github.io/argo-helm

helm repo add grafana https://grafana.github.io/helm-charts
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add kedacore https://kedacore.github.io/charts
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo add defectdojo https://raw.githubusercontent.com/DefectDojo/django-DefectDojo/helm-charts

# Nếu dùng External Secret
helm repo add external-secrets https://charts.external-secrets.io

helm repo update
```

```
# Tại thư mục gốc cd vào thư mục terraform
cd terraform

# Init Terraform
terraform init

# Apply Terraform
terraform apply -target=module.iam -target=module.networking -target=module.gke -auto-approve
terraform apply -target=module.k8s-bootstrap -auto-approve
```

```
# Cập nhập file kubeconfig (nhớ đã xác thực và đăng nhập tài khoản Google bằng gcloud CLI)
gcloud container clusters get-credentials devsecops-gke --zone us-central1-a --project nt548-project
```

```
# Observation Deploy
cd ../observation

# Deploy kube-prometheus-stack (Prometheus, Alertmanager, Grafana, kube-state-metrics, node-exporter)
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack -n monitoring  --version 85.2.0 --values ./prometheus-stack/values.yaml --wait --timeout 10m

kubectl apply -f ./prometheus-stack/rules/nt548-alerts.yaml
kubectl apply -f ./prometheus-stack/rules/nt548-scenario3-security-alerts.yaml
kubectl apply -f ./prometheus-stack/monitors/
kubectl apply -f ./prometheus-stack/dashboards/scenario2-keda-dashboard-configmap.yaml

# Deploy Loki bằng Helm 
helm upgrade --install loki grafana/loki -n logging --version 7.0.0 --values ./loki/values.yaml --wait --timeout 10m

# Deploy Jaeger bằng Helm 
helm upgrade --install jaeger jaegertracing/jaeger -n tracing --version 4.8.0 --values ./jaeger/values.yaml --wait --timeout 10m

# Deploy Promtail for app container logs. Grafana is installed by kube-prometheus-stack above.
# Standalone Grafana is deprecated. Grafana is installed by kube-prometheus-stack.
helm upgrade --install promtail grafana/promtail -n logging --version 6.17.1 --values ./promtail/values.yaml --wait --timeout 10m

# Deploy Otel Collector bằng Helm 
helm upgrade --install otel-gateway open-telemetry/opentelemetry-collector -n monitoring --version 0.156.0 --values ./otel-gateway/values.yaml --wait --timeout 10m

# Deploy Otel Agent bằng Helm 
helm upgrade --install otel-agent open-telemetry/opentelemetry-collector -n monitoring --values ./otel-agent/values.yaml --wait --timeout 10m
```

```
# Apply K8s manifest
cd ../../k8s-manifest
kubectl apply -f ./common
```

```
# Deploy and Apply External Secrets (nếu dùng)
helm upgrade --install eso external-secrets/external-secrets -n security --wait --timeout 10m --set installCRDs=true

kubectl apply -f ./eso
```

```
# Security Deploy cho kịch bản 3 production
cd ../helm-chart

helm upgrade --install kyverno kyverno/kyverno -n kyverno --create-namespace --version 3.8.1 --values ./security/kyverno-values.yaml --wait --timeout 10m

helm upgrade --install falco falcosecurity/falco -n security --create-namespace --version 8.0.5 --values ./security/falco-values.yaml --wait --timeout 10m

helm upgrade --install defectdojo defectdojo/defectdojo -n defectdojo --create-namespace --version 1.9.28 --values ./defectdojo/values.yaml --wait --timeout 15m

cd ..
kubectl apply -f ./k8s-manifest/security/scenario3-production.yaml
kubectl apply -f ./helm-chart/observation/prometheus-stack/rules/nt548-scenario3-security-alerts.yaml
```

---

## Các lệnh xóa hạ tầng

```
cd terraform

# Apply Terraform
terraform destroy -target=module.k8s-bootstrap -auto-approve
terraform destroy -target=module.iam -target=module.networking -target=module.gke -auto-approve
```

---

## Danh sách các URL truy cập vào các tool

Tất cả URL public dưới đây dùng HTTPS với certificate Let's Encrypt.

| Thành phần | URL | Credential demo |
| --- | --- | --- |
| Microservice Web | https://app.vuongdevops.io.vn | Không cần login |
| Jenkins | https://jenkins.vuongdevops.io.vn | `admin/admin` |
| SonarQube | https://sonarqube.vuongdevops.io.vn | `admin/admin` |
| Harbor | https://harbor.vuongdevops.io.vn | `admin/admin` |
| HashiCorp Vault | https://vault.vuongdevops.io.vn | Token auth; nếu cần user/pass demo, enable `userpass` bằng root token rồi tạo user `admin/admin` |
| ArgoCD | https://argocd.vuongdevops.io.vn | `admin/admin` |
| Argo Rollouts | https://argorollouts.vuongdevops.io.vn | Không cần login |
| DefectDojo | https://defectdojo.vuongdevops.io.vn | `admin/admin` |
| Grafana | https://grafana.vuongdevops.io.vn | `admin/admin` |
| Jaeger | https://jaeger.vuongdevops.io.vn | Không cần login |

Nếu SonarQube bị đổi password sau demo, reset lại về `admin/admin`:

```
bash demo-scripts/reset-sonarqube-admin.sh
```
