#!/usr/bin/env bash
set -euo pipefail

APP_NAMESPACE="${APP_NAMESPACE:-app}"
KEDA_NAMESPACE="${KEDA_NAMESPACE:-keda}"
MONITORING_NAMESPACE="${MONITORING_NAMESPACE:-monitoring}"

while true; do
  clear
  date
  echo
  echo "KEDA pods"
  kubectl get pods -n "${KEDA_NAMESPACE}" -o wide
  echo
  echo "Frontend deployment and pods"
  kubectl get deploy frontend -n "${APP_NAMESPACE}"
  kubectl get pods -n "${APP_NAMESPACE}" -l app=frontend,pod-template-hash -o wide
  echo
  echo "KEDA ScaledObject and HPA"
  kubectl get scaledobject frontend-rps-scaler -n "${APP_NAMESPACE}" || true
  kubectl get hpa -n "${APP_NAMESPACE}" || true
  echo
  echo "Scenario 2 alert rule"
  kubectl get prometheusrule nt548-scenario2-alerts -n "${MONITORING_NAMESPACE}" || true
  sleep 2
done
