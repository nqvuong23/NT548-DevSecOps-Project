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
    kubernetes_namespace_v1.main
  ]
}

# Cài đặt Cert-Manager (Cần thiết cho SSL/TLS)
resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = var.cert_manager_helm_repo_url
  chart      = "cert-manager"
  namespace  = var.cert_manager_helm_namespace

  timeout = 300

  values = [
    file(var.cert_manager_helm_values_file_path)
  ]

  depends_on = [
    kubernetes_namespace_v1.main,
    helm_release.ingress_nginx
  ]
}

# Cài đặt Jenkins qua Helm
resource "helm_release" "jenkins-release" {
  name       = "jenkins-release"
  repository = var.jenkins_helm_repo_url
  chart      = "jenkins"
  namespace  = var.jenkins_helm_namespace

  timeout = 300

  values = [
    file(var.jenkins_helm_values_file_path)
  ]

  depends_on = [
    kubernetes_namespace_v1.main,
    # kubernetes_manifest.jenkins_rbac
  ]
}

# Cài đặt Sonarqube qua Helm
resource "helm_release" "sonarqube-release" {
  name       = "sonarqube-release"
  repository = var.sonarqube_helm_repo_url
  chart      = "sonarqube"
  namespace  = var.sonarqube_helm_namespace

  timeout = 600

  values = [
    file(var.sonarqube_helm_values_file_path)
  ]

  depends_on = [
    kubernetes_namespace_v1.main
  ]
}

# Cài đặt Harbor qua Helm
resource "helm_release" "harbor" {
  name       = "harbor"
  repository = var.harbor_helm_repo_url
  chart      = "harbor"
  namespace  = var.harbor_helm_namespace

  timeout = 300

  values = [
    file(var.harbor_helm_values_file_path)
  ]

  depends_on = [
    kubernetes_namespace_v1.main
  ]
}

# Cài đặt Vault qua Helm
resource "helm_release" "vault" {
  name       = "vault"
  repository = var.vault_helm_repo_url
  chart      = "vault"
  namespace  = var.vault_helm_namespace

  timeout = 300

  values = [
    file(var.vault_helm_values_file_path)
  ]

  depends_on = [
    kubernetes_namespace_v1.main
  ]
}

# Cài đặt ArgoCD qua Helm
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = var.argocd_helm_repo_url
  chart      = "argo-cd"
  namespace  = var.argocd_helm_namespace

  timeout = 300

  values = [
    file(var.argocd_helm_values_file_path)
  ]

  depends_on = [
    kubernetes_namespace_v1.main
  ]
}

# Cài đặt Argo Rollouts qua Helm
resource "helm_release" "argo_rollouts" {
  name       = "argo-rollouts"
  repository = var.argo_rollouts_helm_repo_url
  chart      = "argo-rollouts"
  namespace  = var.argo_rollouts_helm_namespace

  timeout = 300

  values = [
    file(var.argo_rollouts_helm_values_file_path)
  ]

  depends_on = [
    kubernetes_namespace_v1.main
  ]
}

# resource "kubernetes_manifest" "jenkins_rbac" {
#   manifest = yamldecode(file(var.jenkins_rbac_path))
# }

# resource "kubernetes_manifest" "cert_manager_cluster_issuer" {
#   manifest = yamldecode(file(var.cert_manager_cluster_issuer_path))

#   depends_on = [ helm_release.cert_manager ]
# }

# resource "kubernetes_manifest" "ingress_nginx" {
#   manifest = yamldecode(file(var.ingress_nginx_path))

#  depends_on = [ helm_release.ingress_nginx ]
# }

# resource "kubernetes_manifest" "argo_ssh_auth" {
#   manifest = yamldecode(file(var.argo_ssh_auth_path))

#   depends_on = [ helm_release.argocd ]
# }

# resource "kubernetes_manifest" "argo_application" {
#   manifest = yamldecode(file(var.argo_application_path))

#   depends_on = [ helm_release.argocd ]
# }

# resource "kubernetes_manifest" "harbor_auth" {
#   manifest = yamldecode(file(var.harbor_auth_path))
# }