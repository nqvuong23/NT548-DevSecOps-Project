variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string

  validation {
    condition     = contains(["us-central1", "asia-southeast1"], var.region)
    error_message = "Region phải là us-central1 hoặc asia-southeast1."
  }
}

variable "nginx_ip_name" {
  type = string
}

variable "dns_zone_name" {
  type = string
}

variable "gg_apis" {
  type = list(string)
}

variable "public_cidr_range" {
  type = string
}

variable "private_cidr_range" {
  type = string
}

variable "gke_pod_cidr_range" {
  type = string
}

variable "gke_service_cidr_range" {
  type = string
}

variable "gke_cluster_name" {
  description = "Tên GKE cluster"
  type        = string
}

variable "gke_master_ipv4_cidr_block" {
  description = "CIDR block cho GKE master endpoint (private cluster)"
  type        = string
}

variable "gke_platform_node_pool_count" {
  type = number
}

variable "gke_platform_node_pool_machine_type" {
  type = string
}

variable "gke_observation_node_pool_count" {
  type = number
}

variable "gke_observation_node_pool_machine_type" {
  type = string
}

variable "gke_app_node_pool_min_count" {
  type = number
}

variable "gke_app_node_pool_max_count" {
  type = number
}

variable "gke_app_node_pool_machine_type" {
  type = string
}

variable "gke_namespaces" {
  type = list(string)
}

variable "nginx_helm_repo_url" {
  type = string
}

variable "nginx_helm_namespace" {
  type = string
}

variable "cert_manager_helm_repo_url" {
  type = string
}

variable "cert_manager_helm_namespace" {
  type = string
}
