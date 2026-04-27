output "vpc_id" {
  description = "The ID of the VPC"
  value       = google_compute_network.vpc.id
}

output "vpc_name" {
  description = "The Name of the VPC"
  value       = google_compute_network.vpc.name
}

output "gke_subnet_name" {
  description = "The Name of the GKE Subnet"
  value       = google_compute_subnetwork.gke_subnet.name
}

output "platform_subnet_name" {
  description = "The Name of the Platform Subnet"
  value       = google_compute_subnetwork.platform_subnet.name
}

output "gke_pod_secondary_range_name" {
  description = "The Name of the GKE Pod secondary range"
  value       = google_compute_subnetwork.gke_subnet.secondary_ip_range[0].range_name
}

output "gke_service_secondary_range_name" {
  description = "The Name of the GKE Service secondary range"
  value       = google_compute_subnetwork.gke_subnet.secondary_ip_range[1].range_name
}

output "ingress_static_ip" {
  description = "The Static IP address for Ingress NGINX"
  value       = google_compute_global_address.ingress_static_ip.address
}