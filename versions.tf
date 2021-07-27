terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "3.52.0"
    }
  }
  required_version = "1.0.2"

  backend "gcs" {
    bucket = "terraform-state-file"
    prefix = "terraform/state"
  }

}

