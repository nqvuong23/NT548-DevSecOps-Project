locals {
  nginx_values_path         = "${path.root}/../helm-chart/ingress-nginx/values.yaml"
  cert_manager_values_path  = "${path.root}/../helm-chart/cert-manager/values.yaml"
  jenkins_values_path       = "${path.root}/../helm-chart/jenkins/values.yaml"
  sonarqube_values_path     = "${path.root}/../helm-chart/sonarqube/values.yaml"
  harbor_values_path        = "${path.root}/../helm-chart/harbor/values.yaml"
  vault_values_path         = "${path.root}/../helm-chart/vault-hashicorp/values.yaml"
  argocd_values_path        = "${path.root}/../helm-chart/argocd/values.yaml"
  argo_rollouts_vaules_path = "${path.root}/../helm-chart/argo-rollouts/values.yaml"

  jenkins_rbac_path                = "${path.root}/../helm-chart/jenkins/rbac.yaml"
  cert_manager_cluster_issuer_path = "${path.root}/../helm-chart/cert-manager/cluster_issuer.yaml"
  ingress_nginx_path               = "${path.root}/../helm-chart/ingress-nginx/ingress.yaml"
  argo_ssh_auth_path               = "${path.root}/../helm-chart/argocd/argo_repo_ssh.yaml"
  argo_application_path            = "${path.root}/../helm-chart/argocd/microservice_app.yaml"
  harbor_auth_path                 = "${path.root}/../helm-chart/argocd/harbor_auth.yaml"
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

  namespaces                  = var.gke_namespaces
  nginx_helm_namespace        = var.nginx_helm_namespace
  nginx_helm_repo_url         = var.nginx_helm_repo_url
  nginx_helm_values_file_path = local.nginx_values_path
  nginx_static_ip             = module.networking.nginx-ip

  cert_manager_helm_namespace        = var.cert_manager_helm_namespace
  cert_manager_helm_repo_url         = var.cert_manager_helm_repo_url
  cert_manager_helm_values_file_path = local.cert_manager_values_path

  jenkins_helm_namespace        = var.jenkins_helm_namespace
  jenkins_helm_repo_url         = var.jenkins_helm_repo_url
  jenkins_helm_values_file_path = local.jenkins_values_path

  sonarqube_helm_namespace        = var.sonarqube_helm_namespace
  sonarqube_helm_repo_url         = var.sonarqube_helm_repo_url
  sonarqube_helm_values_file_path = local.sonarqube_values_path

  harbor_helm_namespace        = var.harbor_helm_namespace
  harbor_helm_repo_url         = var.harbor_helm_repo_url
  harbor_helm_values_file_path = local.harbor_values_path

  vault_helm_namespace        = var.vault_helm_namespace
  vault_helm_repo_url         = var.vault_helm_repo_url
  vault_helm_values_file_path = local.vault_values_path

  argocd_helm_namespace        = var.argocd_helm_namespace
  argocd_helm_repo_url         = var.argo_helm_repo_url
  argocd_helm_values_file_path = local.argocd_values_path

  argo_rollouts_helm_namespace        = var.argo_rollouts_helm_namespace
  argo_rollouts_helm_repo_url         = var.argo_helm_repo_url
  argo_rollouts_helm_values_file_path = local.argo_rollouts_vaules_path

  jenkins_rbac_path                = local.jenkins_rbac_path
  cert_manager_cluster_issuer_path = local.cert_manager_cluster_issuer_path
  ingress_nginx_path               = local.ingress_nginx_path
  argo_application_path            = local.argo_application_path
  argo_ssh_auth_path               = local.argo_ssh_auth_path
  harbor_auth_path                 = local.harbor_auth_path

  depends_on = [module.gke]
}
