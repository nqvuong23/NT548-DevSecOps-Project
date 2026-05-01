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
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = "app"

  set = [
    {
      name  = "controller.ingressClassResource.name"
      value = "nginx"
    },
    {
      name  = "controller.service.externalTrafficPolicy"
      value = "Local"
    }
  ]
}

# Cài đặt Cert-Manager (Cần thiết cho SSL/TLS)
resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  namespace  = "security"
  version    = "v1.20.2"

  set = [
    {
      name  = "installCRDs"
      value = "true"
    }
  ]
}
