terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "3.52.0"
    }
    kubernetes = {
      load_config_file = false
    }
  }
  required_version = "1.0.2"

  backend "gcs" {
    bucket = "hack-hsp-infinities-tf"
    prefix = "terraform/state"
  }

}

