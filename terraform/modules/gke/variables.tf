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
  default     = "us-central1-a"
}

variable "cluster_name" {
  description = "Tên GKE cluster"
  type        = string
  default     = "devsecops-gke"
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
  default     = "172.16.0.0/28"
}
