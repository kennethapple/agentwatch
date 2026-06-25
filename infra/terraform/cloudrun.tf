resource "google_artifact_registry_repository" "agentwatch" {
  location      = var.region
  repository_id = "agentwatch"
  format        = "DOCKER"
  project       = var.project_id

  depends_on = [google_project_service.apis]
}

# Agent service
resource "google_cloud_run_v2_service" "agent" {
  name     = "agentwatch-agent"
  location = var.region
  project  = var.project_id

  template {
    service_account = google_service_account.agent_sa.email

    scaling {
      min_instance_count = 0
      max_instance_count = 10
    }

    containers {
      image = var.agent_image

      env {
        name  = "GCP_PROJECT_ID"
        value = var.project_id
      }
      env {
        name  = "PUBSUB_TOPIC"
        value = google_pubsub_topic.events.name
      }
      env {
        name = "ANTHROPIC_API_KEY"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.anthropic_api_key.secret_id
            version = "latest"
          }
        }
      }

      resources {
        limits = {
          cpu    = "2"
          memory = "1Gi"
        }
      }
    }
  }

  depends_on = [
    google_project_service.apis,
    google_secret_manager_secret_version.anthropic_api_key,
  ]
}

# Allow unauthenticated invocations of agent (Pub/Sub push uses OIDC token above)
resource "google_cloud_run_v2_service_iam_member" "agent_public" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.agent.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Frontend service
resource "google_cloud_run_v2_service" "frontend" {
  name     = "agentwatch-frontend"
  location = var.region
  project  = var.project_id

  template {
    service_account = google_service_account.frontend_sa.email

    scaling {
      min_instance_count = 0
      max_instance_count = 5
    }

    containers {
      image = var.frontend_image

      env {
        name  = "GCP_PROJECT_ID"
        value = var.project_id
      }
      env {
        name  = "NEXT_PUBLIC_AGENT_URL"
        value = google_cloud_run_v2_service.agent.uri
      }
    }
  }

  depends_on = [google_project_service.apis]
}

resource "google_cloud_run_v2_service_iam_member" "frontend_public" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.frontend.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
