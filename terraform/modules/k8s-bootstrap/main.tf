# Tạo các Namespaces
resource "kubernetes_namespace_v1" "main" {
  for_each = toset(var.namespaces)
  metadata {
    annotations = {
      name = each.value
    }

    labels = {
      managed-by = "terraform"
    }

    name = each.value
  }
}

# Cài đặt Ingress-Nginx qua Helm
resource "helm_release" "ingress_nginx" {
  name       = "ingress-nginx"
  repository = var.nginx_helm_repo_url
  chart      = "ingress-nginx"
  namespace  = var.nginx_helm_namespace

  values = [
    file(var.nginx_helm_values_file_path)
  ]

  set = [
    {
      name  = "controller.service.loadBalancerIP"
      value = var.nginx_static_ip
    }
  ]

  depends_on = [
    kubernetes_namespace_v1.main,
    # helm_release.cert_manager
  ]
}

# Cài đặt Cert-Manager (Cần thiết cho SSL/TLS)
# resource "helm_release" "cert_manager" {
#   name       = "cert-manager"
#   repository = var.cert_manager_helm_repo_url
#   chart      = "cert-manager"
#   namespace  = var.cert_manager_helm_namespace
#   version    = "v1.20.2"

#   timeout = 900

#   values = [
#     file(var.cert_manager_helm_values_file_path)
#   ]
# }
