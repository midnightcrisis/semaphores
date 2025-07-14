# Configure the Google Cloud Provider
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.0"
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# Variables
variable "project_id" {
  description = "GCP Project ID"
  type        = string
  default     = "rizzup-dev"
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP Zone"
  type        = string
  default     = "us-central1-c"
}

variable "machine_type" {
  description = "Machine type for the VM"
  type        = string
  default     = "e2-standard-4"
}

variable "disk_size" {
  description = "Boot disk size in GB"
  type        = number
  default     = 50
}

# VPC Network
resource "google_compute_network" "monitoring_network" {
  name                    = "monitoring-network"
  auto_create_subnetworks = false
}

# Subnet
resource "google_compute_subnetwork" "monitoring_subnet" {
  name          = "monitoring-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.monitoring_network.id
}

# Firewall rules for monitoring services
resource "google_compute_firewall" "monitoring_firewall" {
  name    = "monitoring-firewall"
  network = google_compute_network.monitoring_network.name

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443", "3000", "3100", "9090", "9091", "4317", "4318", "14268", "16686"]
  }

  allow {
    protocol = "udp"
    ports    = ["514"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["monitoring"]
}

# Service Account for the VM
resource "google_service_account" "monitoring_sa" {
  account_id   = "monitoring-service-account"
  display_name = "Monitoring Service Account"
}

# IAM roles for the service account
resource "google_project_iam_member" "monitoring_sa_roles" {
  for_each = toset([
    "roles/container.developer",
    "roles/monitoring.metricWriter",
    "roles/logging.logWriter",
    "roles/stackdriver.resourceMetadata.writer"
  ])
  
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.monitoring_sa.email}"
}

# VM Instance
resource "google_compute_instance" "monitoring_vm" {
  name         = "monitoring-vm"
  machine_type = var.machine_type
  zone         = var.zone
  tags         = ["monitoring"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = var.disk_size
    }
  }

  network_interface {
    network    = google_compute_network.monitoring_network.name
    subnetwork = google_compute_subnetwork.monitoring_subnet.name
    
    access_config {
      # Ephemeral public IP
    }
  }

  service_account {
    email  = google_service_account.monitoring_sa.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }

  metadata_startup_script = file("${path.module}/startup-script.sh")
}

# Outputs
output "vm_external_ip" {
  description = "External IP address of the monitoring VM"
  value       = google_compute_instance.monitoring_vm.network_interface[0].access_config[0].nat_ip
}

output "vm_internal_ip" {
  description = "Internal IP address of the monitoring VM"
  value       = google_compute_instance.monitoring_vm.network_interface[0].network_ip
}

output "vm_name" {
  description = "Name of the monitoring VM"
  value       = google_compute_instance.monitoring_vm.name
}

output "project_id" {
  description = "GCP Project ID"
  value       = var.project_id
}