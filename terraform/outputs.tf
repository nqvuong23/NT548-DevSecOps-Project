# Xuất thông tin Mạng (VPC & Subnet) từ module networking
output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.networking.vpc_id
}

output "vpc_name" {
  description = "The Name of the VPC"
  value       = module.networking.vpc_name
}

output "gke_subnet_name" {
  description = "The Name of the GKE Subnet"
  value       = module.networking.gke_subnet_name
}

# Xuất thông tin Service Account Email để module GKE sử dụng
output "gke_service_account_email" {
  description = "Email of the GKE Service Account"
  value       = google_service_account.gke_sa.email
}

output "jenkins_service_account_email" {
  description = "Email of the Jenkins Service Account"
  value       = google_service_account.jenkins_sa.email
}

output "argocd_service_account_email" {
  description = "Email of the ArgoCD Service Account"
  value       = google_service_account.argocd_sa.email
}

output "gke_pod_secondary_range_name" {
  description = "The Name of the GKE Pod secondary range"
  value       = module.networking.gke_pod_secondary_range_name
}

output "gke_service_secondary_range_name" {
  description = "The Name of the GKE Service secondary range"
  value       = module.networking.gke_service_secondary_range_name
}


output "ingress_static_ip" {
  description = "The Static IP address for Ingress NGINX"
  value       = module.networking.ingress_static_ip
}

# Xuất thông tin GKE Cluster
output "gke_cluster_name" {
  description = "The Name of the GKE Cluster"
  value       = module.gke.cluster_name
}

output "gke_cluster_endpoint" {
  description = "The Endpoint of the GKE Cluster API server"
  value       = module.gke.cluster_endpoint
  sensitive   = true
}

output "gke_cluster_location" {
  description = "The Location of the GKE Cluster"
  value       = module.gke.cluster_location
}

output "kubeconfig_command" {
  description = "Lệnh gcloud để cấu hình kubeconfig kết nối cluster"
  value       = module.gke.kubeconfig_command
}