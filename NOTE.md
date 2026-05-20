## Các lệnh triển khai hạ tầng Terraform (Nhớ chạy theo đúng thứ tự)

```
# Tại thư mục gốc cd vào thư mục terraform
cd terraform

# Add Helm Chart Repo 
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add jenkins https://charts.jenkins.io
helm repo add sonarqube https://SonarSource.github.io/helm-chart-sonarqube
helm repo add harbor https://helm.goharbor.io

helm repo add grafana https://grafana.github.io/helm-charts
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add kedacore https://kedacore.github.io/charts
helm repo update

# Init Terraform
terraform init

# Apply Terraform
terraform apply -target=module.iam -target=module.networking -target=module.gke -auto-approve
terraform apply -target=module.k8s-bootstrap -auto-approve

# Cập nhập file kubeconfig (nhớ đã xác thực và đăng nhập tài khoản Google bằng gcloud CLI)
gcloud container clusters get-credentials devsecops-gke --zone us-central1-a --project nt548-project

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

# Observation Deploy
cd ../observation

# Deploy kube-prometheus-stack (Prometheus, Alertmanager, Grafana, kube-state-metrics, node-exporter)
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack -n monitoring --create-namespace --version 85.2.0 --values ./prometheus-stack/values.yaml --wait --timeout 15m
kubectl apply -f ./prometheus-stack/rules/nt548-alerts.yaml
kubectl apply -f ./prometheus-stack/monitors/
kubectl apply -f ./prometheus-stack/dashboards/scenario2-keda-dashboard-configmap.yaml

# Deploy Loki bằng Helm 
helm upgrade --install loki grafana/loki -n logging --create-namespace --version 7.0.0 --values ./loki/values.yaml --wait --timeout 10m

# Deploy Jaeger bằng Helm 
helm upgrade --install jaeger jaegertracing/jaeger -n tracing --create-namespace --version 4.8.0 --values ./jaeger/values.yaml --wait --timeout 10m

# Deploy Promtail for app container logs. Grafana is installed by kube-prometheus-stack above.
helm upgrade --install promtail grafana/promtail -n logging --version 6.17.1 --values ./promtail/values.yaml --wait --timeout 10m

# Standalone Grafana is deprecated. Grafana is installed by kube-prometheus-stack.

# Deploy Otel Collector bằng Helm 
helm upgrade --install otel-gateway open-telemetry/opentelemetry-collector -n monitoring --version 0.156.0 --values ./otel-gateway/values.yaml --wait --timeout 10m

# Deploy Otel Agent bằng Helm 
helm upgrade --install otel-agent open-telemetry/opentelemetry-collector -n monitoring --version 0.156.0 --values ./otel-agent/values.yaml --wait --timeout 10m

# Apply Ingress để forward route tới các service thông qua DNS
cd ../ingress-nginx
# Refresh the existing Terraform-installed ingress-nginx release so metrics are enabled.
helm upgrade ingress-nginx ingress-nginx/ingress-nginx -n app --reuse-values --values ./values.yaml --wait --timeout 10m
kubectl apply -f ./ingress.yaml

# KEDA Scenario 2: install KEDA, then apply the frontend ScaledObject after the app is deployed
cd ../keda
helm upgrade --install keda kedacore/keda -n keda --create-namespace --version 2.19.0 --values ./values.yaml --wait --timeout 10m
kubectl apply -f ./scaledobjects/frontend-rps-scaledobject.yaml
```

---

## Hướng Dẫn Cấu Hình Thủ Công (UI) Sau Khi Deploy GKE

Mỗi khi hệ thống được tạo mới bằng lệnh `terraform apply`, dữ liệu của Jenkins và SonarQube sẽ bị reset. Cần thực hiện các bước cấu hình UI dưới đây để kết nối 2 công cụ này lại với nhau trước khi chạy Pipeline.

### PHẦN 1: Cấu hình trên SonarQube

**Bước 1: Đăng nhập**

Do SonarQube đang chạy bảo mật bên trong mạng nội bộ của K8s, cần tạo đường hầm (port-forward) để truy cập:
1. Mở Terminal/CMD và chạy lệnh sau (lưu ý: giữ nguyên cửa sổ Terminal này trong suốt quá trình sử dụng):
```bash
kubectl port-forward svc/sonarqube-release-sonarqube 9000:9000 -n sonarqube
```
2. Mở trình duyệt web và truy cập: http://localhost:9000
3. Đăng nhập bằng tài khoản mặc định (Username: admin, Password: admin).

**Bước 2: Tạo Project**
1. Chọn tab **Projects** trên thanh menu trên cùng.
2. Bấm **Create a local project**.
3. Tại ô *Project display name* và *Project key*, nhập chính xác tên: `DevSecOps_Nhom10`.
4. Chọn **Follows the instance's default**
5. Bấm **Creat project**.

**Bước 3: Tạo Token để cấp quyền cho Jenkins**
1. Chọn dự án **DevSecOps_Nhom10** vừa tạo.
2. Tại **Project onboarding** chọn **Locally**.
3. Ở phần *Generate Tokens*:
   - Name: Nhập tên tùy ý (VD: `jenkins-token`).
   - Type: Chọn `Global Analysis Token` (hoặc Project Token).
   - Expires in: Chọn `No expiration`.
4. Bấm **Generate**. 
5. **QUAN TRỌNG:** Copy ngay đoạn mã Token vừa hiện ra và lưu tạm ra Notepad (vì nó chỉ hiện 1 lần duy nhất).

**Bước 4: Thiết lập Webhook (Quality Gate)**
1. Quay lại trang chủ SonarQube, bấm vào dự án `DevSecOps_Nhom10` vừa tạo.
2. Chọn menu **Project Settings** > **Webhooks**.
3. Bấm **Create** và điền thông tin:
   - Name: `Jenkins Webhook`
   - URL: `http://jenkins-release.jenkins.svc.cluster.local:8080/sonarqube-webhook/`
4. Bấm **Create** để lưu lại.

---

### PHẦN 2: Cấu hình trên Jenkins

**Bước 1: Đăng nhập**
1. Mở trình duyệt web và truy cập thẳng vào: **http://jenkins.vuongdevops.io.vn**
*(Nếu Ingress chưa chạy hoặc chưa cấu hình file hosts, có thể tạo đường hầm bằng lệnh: `kubectl port-forward svc/jenkins-release 8080:8080 -n jenkins` rồi truy cập `http://localhost:8080`)*
   
2. Để lấy mật khẩu đăng nhập lần đầu của Jenkins, mở Terminal/CMD và chạy lệnh sau:
```bash
kubectl get secret --namespace jenkins jenkins-release -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode
```

3. Copy đoạn mật khẩu vừa hiện ra, quay lại trình duyệt và đăng nhập với Username là admin.

**Bước 2: Lưu Token của SonarQube vào Jenkins**
1. Ở menu bên trái, chọn **Manage Jenkins** > **Credentials**.
2. Nhấp vào domain `(global)` > Bấm **Add Credentials**.
3. Điền các thông tin sau:
   - Kind: Chọn `Secret text`.
   - Secret: Dán đoạn mã Token của SonarQube đã copy ở Phần 1 vào đây.
   - ID: Nhập chính xác là `sonarqube-token` (Bắt buộc phải khớp với ID ghi trong file Jenkinsfile).
   - Description: `Token ket noi SonarQube`.
4. Bấm **Create**.

**Bước 3: Tạo Pipeline Job**
1. Quay ra trang chủ Jenkins, bấm **New Item**.
2. Nhập tên Job: `DevSecOps-Pipeline-Nhom10`.
3. Chọn loại **Pipeline** và bấm **OK**.
4. Cuộn xuống mục **Pipeline**, thiết lập như sau:
   - Definition: Chọn `Pipeline script from SCM`.
   - SCM: Chọn `Git`.
   - Repository URL: Dán link GitHub repo của nhóm vào.
   - Branch Specifier: `*/main`.
   - Script Path: Nhập `jenkins/Jenkinsfile`.
5. Tích vào ô **GitHub hook trigger for GITScm polling** ở mục Build Triggers.
6. Bấm **Save**.

**Bước 4: Cấu hình GitHub Webhook (tự động trigger Pipeline khi push code)**
1. Vào GitHub repo → **Settings** → **Webhooks** → **Add webhook**.
2. Điền thông tin:
   - Payload URL: `http://jenkins.vuongdevops.io.vn/github-webhook/`
   - Content type: `application/json`
   - Which events: chọn **Just the push event**.
3. Bấm **Add webhook**.

---

## Danh sách các URL truy cập vào các tool

- Jenkins URL          : http://jenkins.vuongdevops.io.vn 
- Sonarqueue URL       : http://sonarqube.vuongdevops.io.vn 
- Argocd URL           : http://argocd.vuongdevops.io.vn 
- Harbor URL           : http://harbor.vuongdevops.io.vn 
- Grafana URL          : http://grafana.vuongdevops.io.vn 
- DefectDojo URL       : http://defectdojo.vuongdevops.io.vn 
- Hashicorp Vault URL  : http://vault.vuongdevops.io.vn 
- Jaeger URL           : http://jaeger.vuongdevops.io.vn 

