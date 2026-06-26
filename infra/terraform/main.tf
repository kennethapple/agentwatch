terraform {
  required_version = ">= 1.7"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  # Backend bucket is set by bootstrap.sh before terraform init.
  # If you are a new developer joining the project, ask the project owner
  # for the bucket name and update the value below, or run bootstrap.sh.
  backend "gcs" {
    bucket = "boreal-phoenix-405421-agentwatch-tfstate"
    prefix = "agentwatch"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Enable all required GCP APIs
resource "google_project_service" "apis" {
  for_each = toset([
    "cloudfunctions.googleapis.com",
    "run.googleapis.com",
    "pubsub.googleapis.com",
    "firestore.googleapis.com",
    "secretmanager.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
    "gmail.googleapis.com",
    "storage.googleapis.com",
  ])

  service            = each.value
  disable_on_destroy = false
}




