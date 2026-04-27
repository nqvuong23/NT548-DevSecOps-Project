terraform {
  required_version = ">= 1.3.0"

  # Cấu hình GCS Remote Backend để lưu state
  backend "gcs" {
    bucket = "devsecops-tfstate-devsecops-subject-project"
    prefix = "terraform/state"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}