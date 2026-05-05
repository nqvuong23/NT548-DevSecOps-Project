project_id = "nt548-project"
region     = "us-central1"
gg_apis = [
  "compute.googleapis.com",
  "container.googleapis.com",
  "logging.googleapis.com",
  "secretmanager.googleapis.com"
]

# Network Module
public_cidr_range      = "10.0.0.0/19"
private_cidr_range     = "10.0.32.0/19"
gke_pod_cidr_range     = "172.16.0.0/14"
gke_service_cidr_range = "172.20.0.0/18"
managed_zone_name      = "devsecops-zone"
domain_name            = "vuongdevops.io.vn"
dns_subdomains = [
  "jenkins",
  "sonarqube",
  "argocd",
  "harbor",
  "grafana",
  "defectdojo",
  "vault",
  "jaeger"
]

# GKE Module
gke_cluster_name           = "devsecops-gke"
gke_master_ipv4_cidr_block = "192.168.0.0/28"

gke_platform_node_pool_count           = 2
gke_platform_node_pool_machine_type    = "e2-standard-2"
gke_observation_node_pool_count        = 2
gke_observation_node_pool_machine_type = "e2-standard-2"
gke_app_node_pool_min_count            = 1
gke_app_node_pool_max_count            = 2
gke_app_node_pool_machine_type         = "e2-standard-2"

# K8S-BOOTSTRAP Module
gke_namespaces = [
  "jenkins",
  "sonarqube",
  "argocd",
  "argo-rollouts",
  "vault",
  "harbor",
  "defectdojo",
  "monitoring",
  "logging",
  "tracing",
  "security",
  "app"
]
nginx_helm_namespace        = "app"
nginx_helm_repo_url         = "https://kubernetes.github.io/ingress-nginx"
cert_manager_helm_repo_url  = "oci://quay.io/jetstack/charts"
cert_manager_helm_namespace = "security"
