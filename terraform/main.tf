# Gọi module networking
module "networking" {
  source = "./modules/networking"

  project_id             = var.project_id
  region                 = var.region
  gke_cidr_range         = var.gke_cidr_range
  gke_pod_cidr_range     = var.gke_pod_cidr_range
  gke_service_cidr_range = var.gke_service_cidr_range
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

  namespaces = var.gke_namespaces
}
