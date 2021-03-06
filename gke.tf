variable "gke_username" {
  default     = ""
  description = "gke username"
}

variable "gke_password" {
  default     = ""
  description = "gke password"
}

variable "gke_num_nodes" {
  default     = 3
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
# 
  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
# 
    labels = {
      env = var.project_id
    }
# 
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
  name                = "${var.project_id}-mysql8-storage"
  database_version    = "MYSQL_8_0"
  region              = var.region
  deletion_protection = false
  settings {
    tier            = "db-custom-4-15360"
    disk_size       = 200
    disk_autoresize = true
  }
}

# creating sql database
resource "google_sql_database" "mysql-database" {
  name     = "${var.project_id}-sql-database"
  instance = google_sql_database_instance.mysql.name
}

# creating sql user
resource "google_sql_user" "mysql-user" {
  name     = "${var.project_id}-mysql"
  instance = google_sql_database_instance.mysql.name
  password = var.sql_password
}

# creating workload identity
# resource "google_iam_workload_identity_pool" "hack-hsp-infinities-identity" {
  # provider                  = google-beta
  # workload_identity_pool_id = "${var.project_id}-workload"
# }
# 
# creating workload identity with the above existing service account
# module "my-app-workload-identity" {
  # source              = "terraform-google-modules/kubernetes-engine/google//modules/workload-identity"
  # use_existing_gcp_sa = true
  # name                = "ga-serviceaccount"
  # project_id          = var.project_id
# }

# resource "google_service_account_iam_member" "main" {
  # service_account_id = "projects/hack-hsp-infinities/serviceAccounts/ga-serviceaccount@hack-hsp-infinities.iam.gserviceaccount.com"
  # role               = "roles/iam.workloadIdentityUser"
  # member             = "serviceAccount:hack-hsp-infinities-workload.svc.id.goog[default/ga-serviceaccount]"
# }

# module "hack-hsp-infinities-workload-identity" {
  # source     = "terraform-google-modules/kubernetes-engine/google//modules/workload-identity"
  # name       = "hack-workload-serviceaccount"
  # namespace  = "default"
  # project_id = var.project_id
  # roles      = ["roles/storage.admin", "roles/compute.admin"]
# }

# data "google_container_cluster" "default" {
  # name       = "${var.project_id}-gke"
  # location   = var.region
  # depends_on = [google_container_cluster.primary]
# }
# 
# data "google_client_config" "default" {
  # depends_on = [google_container_cluster.primary]
# }

# provider "kubernetes" {
  # host  = "https://${data.google_container_cluster.default.endpoint}"
  # token = data.google_client_config.default.access_token
  # cluster_ca_certificate = base64decode(
    # data.google_container_cluster.default.master_auth[0].cluster_ca_certificate,
  # )
# }
# 