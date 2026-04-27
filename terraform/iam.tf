# 1. Service Account cho GKE Worker Nodes
resource "google_service_account" "gke_sa" {
  account_id   = "gke-node-sa"
  display_name = "GKE Node Service Account"
}

# Cấp quyền cơ bản cho GKE Node để ghi Log, Metric và kéo Image
resource "google_project_iam_member" "gke_sa_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke_sa.email}"
}

resource "google_project_iam_member" "gke_sa_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke_sa.email}"
}

resource "google_project_iam_member" "gke_sa_artifact" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.gke_sa.email}"
}

# 2. Service Account cho Jenkins (CI)
resource "google_service_account" "jenkins_sa" {
  account_id   = "jenkins-sa"
  display_name = "Jenkins Service Account"
}

# 3. Service Account cho ArgoCD (CD)
resource "google_service_account" "argocd_sa" {
  account_id   = "argocd-sa"
  display_name = "ArgoCD Service Account"
}

# Cấp quyền cho Jenkins SA
resource "google_project_iam_member" "jenkins_sa_artifact" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.jenkins_sa.email}"
}

# TODO Task 1.2: Thay bằng Workload Identity binding với scope giới hạn theo namespace.
# Hiện tại Jenkins chỉ cần quyền đẩy image, không cần quyền K8s trực tiếp để tối ưu bảo mật.
# resource "google_project_iam_member" "jenkins_sa_developer" {
#   project = var.project_id
#   role    = "roles/container.developer"
#   member  = "serviceAccount:${google_service_account.jenkins_sa.email}"
# }

# (Placeholder) ArgoCD Workload Identity Binding sẽ được cấu hình ở module GKE (Task 1.2)