# Lấy thông tin IP đã tạo thủ công
data "google_compute_address" "nginx_ip" {
  name   = var.nginx_ip_name
  region = var.region
}

# Lấy thông tin DNS Zone đã tạo thủ công
data "google_dns_managed_zone" "my_zone" {
  name = var.dns_zone_name
}

# Gọi module networking
module "networking" {
  source = "./modules/networking"

  project_id             = var.project_id
  region                 = var.region
  gke_cidr_range         = var.gke_cidr_range
  gke_pod_cidr_range     = var.gke_pod_cidr_range
  gke_service_cidr_range = var.gke_service_cidr_range
  dns_name               = data.google_dns_managed_zone.my_zone.dns_name
  zone_name              = data.google_dns_managed_zone.my_zone.name
  ip_address             = data.google_compute_address.nginx_ip.address
}

# Gọi module GKE
module "gke" {
  source = "./modules/gke"

  project_id                   = var.project_id
  region                       = var.region
  zone                         = "${var.region}-a"
  cluster_name                 = var.gke_cluster_name
  vpc_name                     = module.networking.vpc_name
  subnet_name                  = module.networking.gke_subnet_name
  pod_secondary_range_name     = module.networking.gke_pod_secondary_range_name
  service_secondary_range_name = module.networking.gke_service_secondary_range_name
  gke_service_account_email    = google_service_account.gke_sa.email
  master_ipv4_cidr_block       = var.gke_master_ipv4_cidr_block

  platform_node_pool_count           = var.gke_platform_node_pool_count
  platform_node_pool_machine_type    = var.gke_platform_node_pool_machine_type
  observation_node_pool_count        = var.gke_observation_node_pool_count
  observation_node_pool_machine_type = var.gke_observation_node_pool_machine_type
  app_node_pool_min_count            = var.gke_app_node_pool_min_count
  app_node_pool_max_count            = var.gke_app_node_pool_max_count
  app_node_pool_machine_type         = var.gke_app_node_pool_machine_type
}

# Gọi module k8s-bootstrap
module "k8s-bootstrap" {
  source = "./modules/k8s-bootstrap"

  namespaces                  = var.gke_namespaces
  nginx_helm_namespace        = var.nginx_helm_namespace
  nginx_helm_repo_url         = var.nginx_helm_repo_url
  nginx_helm_values_file_path = var.nginx_helm_values_file_path
  nginx_static_ip             = data.google_compute_address.nginx_ip.address
  cert_manager_helm_repo_url  = var.cert_manager_helm_repo_url
  cert_manager_helm_namespace = var.cert_manager_helm_namespace
}
