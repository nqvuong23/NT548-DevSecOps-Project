output "vpc_id" {
  description = "The ID of the VPC"
  value       = google_compute_network.vpc.id
}

output "vpc_name" {
  description = "The Name of the VPC"
  value       = google_compute_network.vpc.name
}

output "public_subnet_name" {
  value       = google_compute_subnetwork.public.name
}

output "private_subnet_name" {
  description = "The Name of the GKE Subnet"
  value       = google_compute_subnetwork.private.name
}

output "gke_pod_secondary_range_name" {
  description = "The Name of the GKE Pod secondary range"
  value       = google_compute_subnetwork.private.secondary_ip_range[0].range_name
}

output "gke_service_secondary_range_name" {
  description = "The Name of the GKE Service secondary range"
  value       = google_compute_subnetwork.private.secondary_ip_range[1].range_name
}

output "nginx-ip" {
 value = google_compute_address.nginx.address 
}
