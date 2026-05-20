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
# Deploy Jenkins bằng Helm
cd ../helm-chart/jenkins
kubectl apply -f ./rbac.yaml
helm upgrade --install jenkins-release jenkins/jenkins --namespace jenkins --values ./values.yaml --wait --timeout 10m

# Deploy SonarQube bằng Helm 
cd ../sonarqube
helm upgrade --install sonarqube-release sonarqube/sonarqube --namespace sonarqube --values ./values.yaml --wait --timeout 10m

# Deploy Harbor bằng Helm 
cd ../harbor
helm upgrade --install harbor harbor/harbor --namespace harbor --values ./values.yaml --wait --timeout 10m

# Deploy Hashicorp Vault bằng Helm
cd ../vault-hashicorp
helm upgrade --install vault hashicorp/vault --namespace vault --values ./values.yaml --wait --timeout 10m

# Deploy ArgoCD bằng Helm
cd ../argocd
helm upgrade --install argocd argo/argo-cd -n argocd ---values ./values.yaml --wait --timeout 10m

# Deploy Argo Rollouts bằng Helm
cd ../argo-rollouts
helm upgrade --install argo-rollouts argo/argo-rollouts -n argo-rollouts --values ./values.yaml --wait --timeout 10m
```

```
# Observation Deploy
cd ../observation

# Deploy kube-prometheus-stack (Prometheus, Alertmanager, Grafana, kube-state-metrics, node-exporter)
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack -n monitoring  --version 85.2.0 --values ./prometheus-stack/values.yaml --wait --timeout 10m

kubectl apply -f ./prometheus-stack/rules/nt548-alerts.yaml
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
# Refresh the existing Terraform-installed ingress-nginx release so metrics are enabled.
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx -n app --values ./values.yaml --wait --timeout 10m
```

```
# Apply Ingress để forward route tới các service thông qua DNS
cd ../ingress-nginx
kubectl apply -f ./ingress.yaml
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

- Microservice Web URL : http://app.vuongdevops.io.vn 
- Jenkins URL          : http://jenkins.vuongdevops.io.vn 
- Sonarqueue URL       : http://sonarqube.vuongdevops.io.vn 
- Argocd URL           : http://argocd.vuongdevops.io.vn 
- Harbor URL           : http://harbor.vuongdevops.io.vn 
- Grafana URL          : http://grafana.vuongdevops.io.vn 
- DefectDojo URL       : http://defectdojo.vuongdevops.io.vn 
- Hashicorp Vault URL  : http://vault.vuongdevops.io.vn 
- Jaeger URL           : http://jaeger.vuongdevops.io.vn 

