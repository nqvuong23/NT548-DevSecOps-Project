project_id    = "devsecops-subject-project"
region        = "us-central1"
nginx_ip_name = "nginx-ingress-static-ip"
dns_zone_name = "my-project-dns-zone"

# Network Module
gke_cidr_range         = "10.0.0.0/22"
gke_pod_cidr_range     = "10.1.0.0/16"
gke_service_cidr_range = "10.2.0.0/20"

# GKE Module
gke_cluster_name           = "devsecops-gke"
gke_master_ipv4_cidr_block = "172.16.0.0/28"

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
nginx_helm_values_file_path = "${path.root}/../helm-chart/ingress-nginx/values.yaml"
cert_manager_helm_repo_url  = "https://charts.jetstack.io"
cert_manager_helm_namespace = "security"
