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
