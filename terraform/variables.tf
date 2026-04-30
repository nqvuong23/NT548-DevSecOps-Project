variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"

  validation {
    condition     = contains(["us-central1", "asia-southeast1"], var.region)
    error_message = "Region phải là us-central1 hoặc asia-southeast1."
  }
}
