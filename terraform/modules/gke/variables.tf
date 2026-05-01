variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
}

variable "zone" {
  description = "GCP Zone cho zonal cluster (tránh vượt quota CPUS_ALL_REGIONS)"
  type        = string
}

variable "cluster_name" {
  description = "Tên GKE cluster"
  type        = string
}

variable "vpc_name" {
  description = "Tên VPC network"
  type        = string
}

variable "subnet_name" {
  description = "Tên subnet cho GKE nodes"
  type        = string
}

variable "pod_secondary_range_name" {
  description = "Tên secondary IP range cho Pod"
  type        = string
}

variable "service_secondary_range_name" {
  description = "Tên secondary IP range cho Service"
  type        = string
}

variable "gke_service_account_email" {
  description = "Email của Service Account cho GKE nodes"
  type        = string
}

variable "master_ipv4_cidr_block" {
  description = "CIDR block cho GKE master endpoint (private cluster)"
  type        = string
}

variable "platform_node_pool_count" {
  type = number
}

variable "platform_node_pool_machine_type" {
  type = string
}

variable "observation_node_pool_count" {
  type = number
}

variable "observation_node_pool_machine_type" {
  type = string
}

variable "app_node_pool_min_count" {
  type = number
}

variable "app_node_pool_max_count" {
  type = number
}

variable "app_node_pool_machine_type" {
  type = string
}
