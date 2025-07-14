# GKE cluster configuration for monitoring
# This file contains the GKE cluster setup for the monitoring infrastructure

# Create GKE cluster (if not exists)
resource "google_container_cluster" "monitoring_cluster" {
  name     = "monitoring-cluster"
  location = var.region

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  # Networking
  network    = google_compute_network.monitoring_network.name
  subnetwork = google_compute_subnetwork.monitoring_subnet.name

  # Enable network policy
  network_policy {
    enabled = true
  }

  # Enable monitoring and logging
  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  # Enable workload identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Maintenance window
  maintenance_policy {
    daily_maintenance_window {
      start_time = "03:00"
    }
  }
}

# Create a separately managed node pool
resource "google_container_node_pool" "monitoring_nodes" {
  name       = "monitoring-node-pool"
  location   = var.region
  cluster    = google_container_cluster.monitoring_cluster.name
  node_count = 3

  node_config {
    preemptible  = true
    machine_type = "e2-medium"

    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = google_service_account.monitoring_sa.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = {
      env = "monitoring"
    }

    tags = ["monitoring", "gke-node"]
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}

# Output the cluster connection command
output "gke_cluster_connection_command" {
  description = "Command to connect to the GKE cluster"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.monitoring_cluster.name} --region ${var.region} --project ${var.project_id}"
}