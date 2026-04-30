# =============================================================================
# GKE CLUSTER
# Private cluster, STABLE release channel, Workload Identity, Network Policy
# Zonal cluster (location = zone) để tránh vượt quota CPUS_ALL_REGIONS
# Regional cluster nhân node_count × 3 zones → tốn gấp 3 lần CPU quota
# =============================================================================

resource "google_container_cluster" "primary" {
  name = var.cluster_name

  # Zonal cluster: dùng zone thay vì region
  # Regional cluster (region) = node_count × 3 zones → vượt quota CPUS_ALL_REGIONS
  location = var.zone

  # Xóa default node pool, sử dụng 3 node pool riêng bên dưới
  remove_default_node_pool = true
  initial_node_count       = 1

  # Cấu hình cho default node pool tạm (sẽ bị xóa) để tránh lỗi SSD quota
  node_config {
    disk_type    = "pd-standard"
    disk_size_gb = 20
  }

  # Tắt deletion protection để terraform destroy hoạt động
  deletion_protection = false

  # --- Networking ---
  network    = var.vpc_name
  subnetwork = var.subnet_name

  # VPC-native cluster với secondary ranges cho Pod và Service
  ip_allocation_policy {
    cluster_secondary_range_name  = var.pod_secondary_range_name
    services_secondary_range_name = var.service_secondary_range_name
  }

  # Private cluster: nodes không có public IP, master có public endpoint
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  }

  # --- Release Channel ---
  release_channel {
    channel = "STABLE"
  }

  # --- Workload Identity ---
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # --- Network Policy (Dataplane V2 / Cilium) ---
  # ADVANCED_DATAPATH bao gồm NodeLocal DNSCache và network policy enforcement
  datapath_provider = "ADVANCED_DATAPATH"

  # --- Logging: SYSTEM_COMPONENTS + WORKLOADS ---
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  # --- Monitoring: SYSTEM_COMPONENTS + Managed Prometheus ---
  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]

    managed_prometheus {
      enabled = true
    }
  }

  # --- Addons ---
  addons_config {
    # HTTP Load Balancing (GCE Ingress controller)
    http_load_balancing {
      disabled = false
    }

    # Horizontal Pod Autoscaling
    horizontal_pod_autoscaling {
      disabled = false
    }

    # GCS Fuse CSI Driver — mount GCS buckets vào Pod
    gcs_fuse_csi_driver_config {
      enabled = true
    }
  }
}

# =============================================================================
# NODE POOL: platform-pool
# 2 nodes e2-standard-2, taint/label pool=platform
# CPU: 2 × 2 vCPU = 4 CPUs
# =============================================================================

resource "google_container_node_pool" "platform_pool" {
  name     = "platform-pool"
  location = var.zone
  cluster  = google_container_cluster.primary.name

  node_count = 2

  # Upgrade strategy: rolling update an toàn (surge 1, unavailable 0)
  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type    = "e2-standard-2"
    disk_size_gb    = 50
    disk_type       = "pd-standard"
    service_account = var.gke_service_account_email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    labels = {
      pool = "platform"
    }

    taint {
      key    = "pool"
      value  = "platform"
      effect = "NO_SCHEDULE"
    }

    # Tags cho firewall rules trong networking module
    tags = ["gke-node"]

    # Workload Identity: dùng GKE metadata server thay vì instance metadata
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
}

# =============================================================================
# NODE POOL: observation-pool
# 2 nodes e2-standard-2, taint/label pool=observation
# CPU: 2 × 2 vCPU = 4 CPUs
# =============================================================================

resource "google_container_node_pool" "observation_pool" {
  name     = "observation-pool"
  location = var.zone
  cluster  = google_container_cluster.primary.name

  node_count = 2

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type    = "e2-standard-2"
    disk_size_gb    = 50
    disk_type       = "pd-standard"
    service_account = var.gke_service_account_email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    labels = {
      pool = "observation"
    }

    taint {
      key    = "pool"
      value  = "observation"
      effect = "NO_SCHEDULE"
    }

    tags = ["gke-node"]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
}

# =============================================================================
# NODE POOL: app-pool
# Autoscaling min=1 max=2, e2-standard-2, taint/label pool=app
# CPU: min=1 × 2 vCPU = 2 CPUs (min), max=2 × 2 vCPU = 4 CPUs (max)
# =============================================================================

resource "google_container_node_pool" "app_pool" {
  name     = "app-pool"
  location = var.zone
  cluster  = google_container_cluster.primary.name

  # Autoscaling: cluster autoscaler tự scale trong [min, max]
  autoscaling {
    min_node_count = 1
    max_node_count = 2
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type    = "e2-standard-2"
    disk_size_gb    = 50
    disk_type       = "pd-standard"
    service_account = var.gke_service_account_email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    labels = {
      pool = "app"
    }

    taint {
      key    = "pool"
      value  = "app"
      effect = "NO_SCHEDULE"
    }

    tags = ["gke-node"]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
}
