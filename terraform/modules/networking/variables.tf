variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region (ví dụ: us-central1)"
  type        = string
}

variable "gke_cidr_range" {
  type = string
}

variable "gke_pod_cidr_range" {
  type = string
}

variable "gke_service_cidr_range" {
  type = string
}

variable "allow_ingress_source_ranges" {
  type = list(string)
  default = [ "0.0.0.0/0" ]
}

variable "allow_health_check_source_ranges" {
  type = list(string)
  default = ["130.211.0.0/22", "35.191.0.0/16"]
}
