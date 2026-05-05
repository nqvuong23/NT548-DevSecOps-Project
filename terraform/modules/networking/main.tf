# Tạo VPC Network
resource "google_compute_network" "vpc" {
  name                            = "devsecops-vpc"
  auto_create_subnetworks         = false
  routing_mode                    = "REGIONAL"
  delete_default_routes_on_create = true
}

# Default route
resource "google_compute_route" "default_route" {
  name             = "default-route"
  dest_range       = "0.0.0.0/0"
  network          = google_compute_network.vpc.name
  next_hop_gateway = "default-internet-gateway"
}

resource "google_compute_subnetwork" "public" {
  name                     = "public-subnet"
  ip_cidr_range            = var.public_cidr_range
  region                   = var.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true
  stack_type               = "IPV4_ONLY"
}

# Tạo Subnet cho GKE Cluster
resource "google_compute_subnetwork" "private" {
  name                     = "private-subnet"
  ip_cidr_range            = var.private_cidr_range
  region                   = var.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true
  stack_type               = "IPV4_ONLY"

  # Cấu hình Secondary Ranges cho Pod và Service
  secondary_ip_range {
    range_name    = "gke-pod-range"
    ip_cidr_range = var.gke_pod_cidr_range
  }

  secondary_ip_range {
    range_name    = "gke-service-range"
    ip_cidr_range = var.gke_service_cidr_range
  }
}

# Tạo Cloud Router
resource "google_compute_router" "router" {
  name    = "devsecops-router"
  region  = var.region
  network = google_compute_network.vpc.id
}

resource "google_compute_address" "nat" {
  name         = "devsecops-nat"
  address_type = "EXTERNAL"
  network_tier = "PREMIUM"
}

# Tạo Cloud NAT để private node ra được internet
resource "google_compute_router_nat" "nat" {
  name   = "devsecops-nat"
  region = var.region
  router = google_compute_router.router.name

  nat_ip_allocate_option             = "MANUAL_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  nat_ips                            = [google_compute_address.nat.self_link]

  subnetwork {
    name                    = google_compute_subnetwork.private.self_link
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}

resource "google_compute_address" "nginx" {
  name         = "nginx-ip"
  address_type = "EXTERNAL"
  network_tier = "PREMIUM"
}

resource "google_dns_record_set" "record" {
  for_each = toset(var.dns_subdomains)
  
  name = "${each.value}.${var.domain_name}."
  type = "A"
  ttl  = 300

  managed_zone = var.managed_zone_name

  rrdatas = [google_compute_address.nginx.address]
}

# Firewall Rule: Allow Internal Traffic
resource "google_compute_firewall" "gke_internal" {
  name    = "gke-internal"
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

  source_ranges = [var.private_cidr_range, var.gke_pod_cidr_range, var.gke_service_cidr_range]
  target_tags   = ["gke-node"]
}

resource "google_compute_firewall" "gke_master_to_nodes" {
  name    = "gke-master-to-worker-admin"
  network = google_compute_network.vpc.id

  allow {
    protocol = "tcp"
    ports    = ["10250", "443"] # 10250 cho Kubelet logs/exec, 443 cho webhook/konnectivity
  }

  # Nguồn là dải IP của Master Node (Control Plane)
  source_ranges = [var.gke_master_ipv4_cidr_block]

  # Đích là các Worker Nodes (nhận diện qua network tag)
  target_tags = ["gke-node"]

  description = "Allow GKE Master to communicate with nodes for logs and admission webhooks"
}

# Firewall Rule: Allow Ingress (Load Balancer ports 80/443)
resource "google_compute_firewall" "allow_ingress" {
  name    = "allow-ingress"
  network = google_compute_network.vpc.id

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = var.allow_ingress_source_ranges
}

# Firewall Rule: Allow Health Check từ Google Load Balancer
resource "google_compute_firewall" "allow_health_check" {
  name    = "allow-health-check"
  network = google_compute_network.vpc.id

  allow {
    protocol = "tcp"
  }

  source_ranges = var.allow_health_check_source_ranges
  target_tags   = ["gke-node"]
}
