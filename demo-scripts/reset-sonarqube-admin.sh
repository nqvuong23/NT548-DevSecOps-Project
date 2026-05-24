#!/usr/bin/env bash
set -Eeuo pipefail

NAMESPACE="${NAMESPACE:-sonarqube}"
STATEFULSET="${STATEFULSET:-sonarqube-release-sonarqube}"
PVC="${PVC:-sonarqube-release-sonarqube}"
TOOL_POD="${TOOL_POD:-sonar-h2-tools}"

log() {
  printf '[sonarqube-reset] %s\n' "$*"
}

kubectl get namespace "${NAMESPACE}" >/dev/null

image="$(kubectl -n "${NAMESPACE}" get sts "${STATEFULSET}" -o jsonpath='{.spec.template.spec.containers[0].image}')"
replicas="$(kubectl -n "${NAMESPACE}" get sts "${STATEFULSET}" -o jsonpath='{.spec.replicas}')"

sql_file="$(mktemp)"
cat >"${sql_file}" <<'SQL'
update users set
  crypted_password='100000$t2h8AtNs1AlCHuLobDjHQTn9XppwTIx88UjqUm4s8RsfTuXQHSd/fpFexAnewwPsO6jGFQUv/24DnO55hY6Xew==',
  salt='k9x9eN127/3e/hf38iNiKwVfaVk=',
  hash_method='PBKDF2',
  reset_password=false,
  user_local=true,
  active=true,
  updated_at=datediff('MILLISECOND', timestamp '1970-01-01 00:00:00', current_timestamp())
where login='admin';
select login, hash_method, reset_password, active from users where login='admin';
SQL

cleanup() {
  rm -f "${sql_file}"
  kubectl -n "${NAMESPACE}" delete pod "${TOOL_POD}" --ignore-not-found=true --wait=false >/dev/null 2>&1 || true
}
trap cleanup EXIT

log "Scaling ${STATEFULSET} down so the H2 database is not locked"
kubectl -n "${NAMESPACE}" scale sts "${STATEFULSET}" --replicas=0 >/dev/null
kubectl -n "${NAMESPACE}" wait pod -l app=sonarqube --for=delete --timeout=180s || true

kubectl -n "${NAMESPACE}" delete pod "${TOOL_POD}" --ignore-not-found=true --wait=true >/dev/null
cat >/tmp/sonar-h2-pod.json <<JSON
{"apiVersion":"v1","kind":"Pod","metadata":{"name":"${TOOL_POD}","namespace":"${NAMESPACE}"},"spec":{"restartPolicy":"Never","containers":[{"name":"tools","image":"${image}","command":["sleep","3600"],"volumeMounts":[{"name":"sonarqube","mountPath":"/data"}]}],"volumes":[{"name":"sonarqube","persistentVolumeClaim":{"claimName":"${PVC}"}}]}}
JSON
kubectl apply -f /tmp/sonar-h2-pod.json >/dev/null
kubectl -n "${NAMESPACE}" wait pod/"${TOOL_POD}" --for=condition=Ready --timeout=180s >/dev/null
kubectl cp "${sql_file}" "${NAMESPACE}/${TOOL_POD}:/tmp/reset-admin.sql" >/dev/null

kubectl -n "${NAMESPACE}" exec "${TOOL_POD}" -- sh -c '
set -e
JAR=$(ls /opt/sonarqube/lib/jdbc/h2/h2-*.jar | head -1)
URL="jdbc:h2:/data/data/sonar;IFEXISTS=TRUE"
backup="/data/data/sonar.mv.db.bak-$(date +%Y%m%d%H%M%S)"
cp /data/data/sonar.mv.db "$backup"
echo "backup=$backup"
java -cp "$JAR" org.h2.tools.RunScript -url "$URL" -user "" -password "" -script /tmp/reset-admin.sql -showResults
'

kubectl -n "${NAMESPACE}" delete pod "${TOOL_POD}" --wait=true >/dev/null || true
log "Scaling ${STATEFULSET} back to ${replicas:-1}"
kubectl -n "${NAMESPACE}" scale sts "${STATEFULSET}" --replicas="${replicas:-1}" >/dev/null
kubectl -n "${NAMESPACE}" rollout status sts/"${STATEFULSET}" --timeout=300s
kubectl -n "${NAMESPACE}" wait pod -l app=sonarqube --for=condition=Ready --timeout=300s
log "SonarQube admin password reset to admin/admin"
