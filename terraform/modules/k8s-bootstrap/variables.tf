variable "namespaces" {
  type    = list(string)
}

variable "nginx_helm_repo_url" {
  type = string
}

variable "nginx_helm_namespace" {
  type = string
}

variable "nginx_helm_values_file_path" {
  type = string
}

variable "nginx_static_ip" {
  type = string
}

variable "cert_manager_helm_repo_url" {
  type = string
}

variable "cert_manager_helm_namespace" {
  type = string
}

variable "cert_manager_helm_values_file_path" {
  type = string
}


variable "jenkins_helm_repo_url" {
  type = string
}

variable "jenkins_helm_namespace" {
  type = string
}

variable "jenkins_helm_values_file_path" {
  type = string
}

variable "sonarqube_helm_repo_url" {
  type = string
}

variable "sonarqube_helm_namespace" {
  type = string
}

variable "sonarqube_helm_values_file_path" {
  type = string
}

variable "harbor_helm_repo_url" {
  type = string
}

variable "harbor_helm_namespace" {
  type = string
}

variable "harbor_helm_values_file_path" {
  type = string
}

variable "vault_helm_repo_url" {
  type = string
}

variable "vault_helm_namespace" {
  type = string
}

variable "vault_helm_values_file_path" {
  type = string
}

variable "argocd_helm_repo_url" {
  type = string
}

variable "argocd_helm_namespace" {
  type = string
}

variable "argocd_helm_values_file_path" {
  type = string
}

variable "argo_rollouts_helm_repo_url" {
  type = string
}

variable "argo_rollouts_helm_namespace" {
  type = string
}

variable "argo_rollouts_helm_values_file_path" {
  type = string
}

variable "jenkins_rbac_path" {
  type = string
}

variable "cert_manager_cluster_issuer_path" {
  type = string
}

variable "ingress_nginx_path" {
  type = string
}

variable "argo_ssh_auth_path" {
  type = string
}

variable "argo_application_path" {
  type = string
}

variable "harbor_auth_path" {
  type = string
}
