# Tên cluster
output "cluster_name" {
  description = "Tên của GKE cluster"
  value       = google_container_cluster.primary.name
}

# Endpoint API server
output "cluster_endpoint" {
  description = "Endpoint của GKE cluster API server"
  value       = google_container_cluster.primary.endpoint
  sensitive   = true
}

# CA Certificate (base64)
output "cluster_ca_certificate" {
  description = "CA certificate của cluster (base64 encoded)"
  value       = google_container_cluster.primary.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

# Location (zone)
output "cluster_location" {
  description = "Location (zone) của GKE cluster"
  value       = google_container_cluster.primary.location
}

# Lệnh gcloud để cấu hình kubeconfig
# Dùng --zone vì đây là zonal cluster
output "kubeconfig_command" {
  description = "Lệnh gcloud để cấu hình kubeconfig kết nối cluster"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --zone ${google_container_cluster.primary.location} --project ${var.project_id}"
}
