#!/usr/bin/env bash
# ============================================================
# Lưu ý: trước khi chạy script setup.sh
# chạy lệnh "chmod +x setup.sh" để cấp quyền
# sau đó chạy script bằng lệnh "./setup.sh"
# ============================================================

set -euo pipefail

NAMESPACE="jenkins"
RELEASE_NAME="jenkins-release-v1"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JENKINS_HELM_CHART_DIR="${PROJECT_ROOT}/helm-chart/jenkins"

echo ">>> Apply RBAC cho agent..."
kubectl apply -f "${JENKINS_HELM_CHART_DIR}/rbac.yaml"

echo ">>> Add Helm repo..."
helm repo add jenkins https://charts.jenkins.io
helm repo update

echo ">>> Install Jenkins..."
helm upgrade --install "${RELEASE_NAME}" jenkins/jenkins \
  --namespace "${NAMESPACE}" \
  --values "${JENKINS_HELM_CHART_DIR}/values.yaml" \
  --wait \
  --timeout 10m

