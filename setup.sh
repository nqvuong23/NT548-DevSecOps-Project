#!/usr/bin/env bash
# ============================================================
# Lưu ý: trước khi chạy script setup.sh
# chạy lệnh "chmod +x setup.sh" để cấp quyền
# sau đó chạy script bằng lệnh "./setup.sh"
# ============================================================

set -euo pipefail

NAMESPACE="jenkins"
RELEASE_JENKINS_NAME="jenkins-release"
GKE_CLUSTER_NAME="devsecops-gke"
GKE_LOCATION="us-central1-a"
GG_PROJECT_ID="nt548-project"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JENKINS_HELM_CHART_DIR="${PROJECT_ROOT}/helm-chart/jenkins"
NGINX_HELM_CHART_DIR="${PROJECT_ROOT}/helm-chart/ingress-nginx"

echo ">>> Apply Terraform..."
terraform apply -target=module.iam -target=module.networking -target=module.gke -auto-approve
terraform apply -target=module.k8s_bootstrap -auto-approve

echo ">>> Update kubeconfig..."
gcloud container clusters get-credentials "${GKE_CLUSTER_NAME}" --zone "${GKE_LOCATION}" --project "${GG_PROJECT_ID}"

echo ">>> Apply RBAC cho agent..."
kubectl apply -f "${JENKINS_HELM_CHART_DIR}/rbac.yaml"

echo ">>> Add Jenkins Helm repo..."
helm repo add jenkins https://charts.jenkins.io
helm repo update

echo ">>> Install Jenkins Chart..."
helm upgrade --install "${RELEASE_JENKINS_NAME}" jenkins/jenkins \
  --namespace "${NAMESPACE}" \
  --values "${JENKINS_HELM_CHART_DIR}/values.yaml" \
  --wait \
  --timeout 10m

echo ">>> Apply Ingress cho các service..."
kubectl apply -f "${NGINX_HELM_CHART_DIR}/ingress.yaml"
