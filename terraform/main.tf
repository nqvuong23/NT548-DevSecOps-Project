# Gọi module networking
module "networking" {
  source     = "./modules/networking"
  project_id = var.project_id
  region     = var.region
}

# Gọi module GKE
module "gke" {
  source = "./modules/gke"

  project_id                   = var.project_id
  region                       = var.region
  zone                         = "${var.region}-a"
  vpc_name                     = module.networking.vpc_name
  subnet_name                  = module.networking.gke_subnet_name
  pod_secondary_range_name     = module.networking.gke_pod_secondary_range_name
  service_secondary_range_name = module.networking.gke_service_secondary_range_name
  gke_service_account_email    = google_service_account.gke_sa.email
}