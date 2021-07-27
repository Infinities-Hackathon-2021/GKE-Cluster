variable "gke_username" {
  default     = ""
  description = "gke username"
}

variable "gke_password" {
  default     = ""
  description = "gke password"
}

variable "gke_num_nodes" {
  default     = 2
  description = "number of gke nodes"
}

# GKE cluster
resource "google_container_cluster" "primary" {
  name     = "${var.project_id}-gke"
  location = var.region
  
  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name
}

# Separately Managed Node Pool
resource "google_container_node_pool" "primary_nodes" {
  name       = "${google_container_cluster.primary.name}-node-pool"
  location   = var.region
  cluster    = google_container_cluster.primary.name
  node_count = var.gke_num_nodes

  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]

    labels = {
      env = var.project_id
    }

    # preemptible  = true
    machine_type = "n1-standard-1"
    tags         = ["gke-node", "${var.project_id}-gke"]
    metadata = {
      disable-legacy-endpoints = "true"
    }
  }
}

# creating sql instance
resource "google_sql_database_instance" "mysql" {
  name                = "${var.project_id}-sql-storage"
  database_version    = "MYSQL_8_0"
  region              = var.region
  deletion_protection = true
  settings {
    tier = "db-custom-4-15360"
    disk_size       = 200
    disk_autoresize = true
  }
}

# creating sql database
resource "google_sql_database" "sql-database" {
  name     = "${var.project_id}-sql-events"
  instance = google_sql_database_instance.mysql.name
}

# creating sql user
resource "google_sql_user" "sql-user" {
  name     = "${var.project_id}-sql"
  instance = google_sql_database_instance.mysql.name
  password = var.sql_password
}

# using the preexisting service account
resource "google_service_account" "ga-serviceaccount" {
  account_id   = "ga-serviceaccount"
}

# to create a workload
module "my-app-workload-identity" {
  source              = "terraform-google-modules/kubernetes-engine/google//modules/workload-identity"
  use_existing_gcp_sa = true
  name                = google_service_account.ga-serviceaccount.account_id
  project_id          = var.project_id
}

# workload creation with creating a new service account
# module "hack-infinities-workload-identity" {
#   source     = "terraform-google-modules/kubernetes-engine/google//modules/workload-identity"
#   name       = "workload-ServiceAccount"
#   namespace  = "default"
#   project_id = "${var.project_id}"
#   roles      = ["roles/storage.Admin", "roles/compute.Admin"]
# }

# # Kubernetes provider
# # The Terraform Kubernetes Provider configuration below is used as a learning reference only. 
# # It references the variables and resources provisioned in this file. 
# # We recommend you put this in another file -- so you can have a more modular configuration.
# # https://learn.hashicorp.com/terraform/kubernetes/provision-gke-cluster#optional-configure-terraform-kubernetes-provider
# # To learn how to schedule deployments and services using the provider, go here: https://learn.hashicorp.com/tutorials/terraform/kubernetes-provider.

# provider "kubernetes" {
#   load_config_file = "false"

#   host     = google_container_cluster.primary.endpoint
#   username = var.gke_username
#   password = var.gke_password

#   client_certificate     = google_container_cluster.primary.master_auth.0.client_certificate
#   client_key             = google_container_cluster.primary.master_auth.0.client_key
#   cluster_ca_certificate = google_container_cluster.primary.master_auth.0.cluster_ca_certificate
# }

