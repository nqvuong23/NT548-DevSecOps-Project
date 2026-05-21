# Cài kubectl argo rollouts plugin

curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64
chmod +x ./kubectl-argo-rollouts-linux-amd64
sudo mv ./kubectl-argo-rollouts-linux-amd64 /usr/local/bin/kubectl-argo-rollouts

# Cài ArgoCD CLI

curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64

# Deploy root app (App-of-Apps)

cd ../..
kubectl apply -f gitops/root/root-app.yaml

# Login ArgoCD CLI

ARGOCD_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
argocd login argocd.vuongdevops.io.vn --username admin --password "$ARGOCD_PASS" --insecure --grpc-web

# Thêm repo GitHub vào ArgoCD (repo public)

argocd repo add https://github.com/nqvuong23/NT548-DevSecOps-Project.git --name nt548-devsecops --grpc-web

# Refresh và sync root-app

argocd app get root-app --refresh --grpc-web
argocd app sync root-app --grpc-web

# Lay pass trong argocd

kubectl -n argocd get secret argocd-initial-admin-secret \
 -o jsonpath="{.data.password}" | base64 -d && echo

# Cach login

Username: admin
Password: <password vừa lấy ở trên>

# Test hoat dong dung chua

# Kiểm tra ArgoCD pods (phải chạy trên platform-pool)

kubectl get pods -n argocd -o wide

# Kiểm tra Argo Rollouts pods (phải chạy trên platform-pool)

kubectl get pods -n argo-rollouts -o wide

# Kiểm tra Ingress

kubectl get ingress -n argocd
kubectl get ingress -n argo-rollouts

# Kiểm tra Applications (phải Synced/Healthy)

argocd app list --grpc-web

# Kiểm tra AppProjects

kubectl get appprojects -n argocd

# Kiểm tra Microservices pods (phải chạy trên app-pool)

kubectl get pods -n app -o wide

# Kiểm tra kubectl plugin

kubectl argo rollouts version

ArgoCD URL : http://argocd.vuongdevops.io.vn
Argo Rollouts Dashboard : http://argorollouts.vuongdevops.io.vn
