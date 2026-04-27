# Tạo VPC Network
resource "google_compute_network" "vpc" {
  name                    = "devsecops-vpc"
  auto_create_subnetworks = false
}

# Tạo Subnet 1 cho GKE Cluster
resource "google_compute_subnetwork" "gke_subnet" {
  name          = "gke-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id

  # Cấu hình Secondary Ranges cho Pod và Service
  secondary_ip_range {
    range_name    = "gke-pod-range"
    ip_cidr_range = "10.1.0.0/16"
  }

  secondary_ip_range {
    range_name    = "gke-service-range"
    ip_cidr_range = "10.2.0.0/20"
  }
}

# Tạo Subnet 2 cho Platform/Tools
resource "google_compute_subnetwork" "platform_subnet" {
  name          = "platform-subnet"
  ip_cidr_range = "10.0.2.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id
}

# Tạo Cloud Router
resource "google_compute_router" "router" {
  name    = "devsecops-router"
  region  = var.region
  network = google_compute_network.vpc.id
}

# Tạo Cloud NAT để private node ra được internet
resource "google_compute_router_nat" "nat" {
  name                               = "devsecops-nat"
  router                             = google_compute_router.router.name
  region                             = google_compute_router.router.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# Firewall Rule: Allow Internal Traffic
resource "google_compute_firewall" "allow_internal" {
  name    = "allow-internal"
  network = google_compute_network.vpc.id

  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.0.0.0/16", "10.1.0.0/16", "10.2.0.0/20"]
  target_tags   = ["gke-node"] # Giới hạn đối tượng nhận traffic nội bộ
}

# Firewall Rule: Allow Ingress (Load Balancer ports 80/443)
resource "google_compute_firewall" "allow_ingress" {
  name    = "allow-ingress"
  network = google_compute_network.vpc.id

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
}

# Cloud DNS: Private zone cho internal domain
resource "google_dns_managed_zone" "internal_dns" {
  name        = "internal-dns-zone"
  dns_name    = "internal.devsecops.local."
  description = "Private DNS zone for internal tool domains"
  visibility  = "private"

  private_visibility_config {
    networks {
      network_url = google_compute_network.vpc.id
    }
  }
}


# Firewall Rule: Allow Health Check từ Google Load Balancer
resource "google_compute_firewall" "allow_health_check" {
  name    = "allow-health-check"
  network = google_compute_network.vpc.id

  allow {
    protocol = "tcp"
  }

  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["gke-node"]
}

# Tạo Static IP cho Ingress NGINX (Load Balancer)
resource "google_compute_global_address" "ingress_static_ip" {
  name = "ingress-nginx-static-ip"
}