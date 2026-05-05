locals {
  nginx_values_path        = "${path.root}/../helm-chart/ingress-nginx/values.yaml"
  cert_manager_values_path = "${path.root}/../helm-chart/cert-manager/values.yaml"
}

# Gọi moduel iam
module "iam" {
  source = "./modules/iam"

  gg_apis    = var.gg_apis
  project_id = var.project_id
}

# Gọi module networking
module "networking" {
  source = "./modules/networking"

  project_id                 = var.project_id
  region                     = var.region
  public_cidr_range          = var.public_cidr_range
  private_cidr_range         = var.private_cidr_range
  gke_pod_cidr_range         = var.gke_pod_cidr_range
  gke_service_cidr_range     = var.gke_service_cidr_range
  gke_master_ipv4_cidr_block = var.gke_master_ipv4_cidr_block
  dns_subdomains             = var.dns_subdomains
  domain_name                = var.domain_name
  managed_zone_name          = var.managed_zone_name
  depends_on                 = [module.iam]
}

# Gọi module GKE
module "gke" {
  source = "./modules/gke"

  project_id   = var.project_id
  region       = var.region
  zone         = "${var.region}-a"
  cluster_name = var.gke_cluster_name

  vpc_name                     = module.networking.vpc_name
  subnet_name                  = module.networking.private_subnet_name
  pod_secondary_range_name     = module.networking.gke_pod_secondary_range_name
  service_secondary_range_name = module.networking.gke_service_secondary_range_name
  master_ipv4_cidr_block       = var.gke_master_ipv4_cidr_block

  gke_service_account_email = module.iam.gke_sa_email

  platform_node_pool_count           = var.gke_platform_node_pool_count
  platform_node_pool_machine_type    = var.gke_platform_node_pool_machine_type
  observation_node_pool_count        = var.gke_observation_node_pool_count
  observation_node_pool_machine_type = var.gke_observation_node_pool_machine_type
  app_node_pool_min_count            = var.gke_app_node_pool_min_count
  app_node_pool_max_count            = var.gke_app_node_pool_max_count
  app_node_pool_machine_type         = var.gke_app_node_pool_machine_type

  depends_on = [module.networking]
}

# Gọi module k8s-bootstrap
module "k8s-bootstrap" {
  source = "./modules/k8s-bootstrap"

  namespaces                         = var.gke_namespaces
  nginx_helm_namespace               = var.nginx_helm_namespace
  nginx_helm_repo_url                = var.nginx_helm_repo_url
  nginx_helm_values_file_path        = local.nginx_values_path
  nginx_static_ip                    = module.networking.nginx-ip
  cert_manager_helm_repo_url         = var.cert_manager_helm_repo_url
  cert_manager_helm_namespace        = var.cert_manager_helm_namespace
  cert_manager_helm_values_file_path = local.cert_manager_values_path

  depends_on = [module.gke]
}
