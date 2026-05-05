## Các lệnh triển khai hạ tầng Terrfomr (Nhớ chạy theo đúng thứ tự)

```
# Tại thư mục gốc cd vào thư mục terrform
cd devsecops-project/terrform

# Apply Terraform
terraform apply -target=module.iam -target=module.networking -target=module.gke -auto-approve
terraform apply -target=module.k8s_bootstrap -auto-approve

# Cập nhập file kubeconfig (nhớ đã xác thực và đăng nhập tài khoản Google bằng gcloud CLI)
gcloud container clusters get-credentials devsecops-gke --zone us-central1-a --project nt548-project

# Deploy Jenkins bằng Helm
cd ../helm-chart/jenkins
kubectl apply -f ./rbac.yaml
helm repo add jenkins https://charts.jenkins.io
helm repo update
helm upgrade --install jenkins-release jenkins/jenkins --namespace jenkins --values ./values.yaml --wait --timeout 10m

# Apply Ingress để forward route tới các service thông qua DNS
cd ../ingress-nginx
kubectl apply -f ./ingress.yaml"
```

---

## Danh sách các URL truy cập vào các tool

Jenkins URL          : http://jenkins.vuongdevops.io.vn 
Sonarqueue URL       : http://sonarqube.vuongdevops.io.vn 
Argocd URL           : http://argocd.vuongdevops.io.vn 
Harbor URL           : http://harbor.vuongdevops.io.vn 
Grafana URL          : http://grafana.vuongdevops.io.vn 
DefectDojo URL       : http://defectdojo.vuongdevops.io.vn 
Hashicorp Vault URL  : http://vault.vuongdevops.io.vn 
Jaeger URL           : http://jaeger.vuongdevops.io.vn 

