# Dead-letter topic first (no dependencies)
resource "google_pubsub_topic" "events_dlq" {
  name    = "agentwatch-events-dlq"
  project = var.project_id

  depends_on = [google_project_service.apis]
}

# Main events topic
resource "google_pubsub_topic" "events" {
  name    = "agentwatch-events"
  project = var.project_id

  depends_on = [google_project_service.apis]
}

# Push subscription → agent Cloud Run
resource "google_pubsub_subscription" "agent_sub" {
  name    = "agentwatch-agent-sub"
  topic   = google_pubsub_topic.events.name
  project = var.project_id

  push_config {
    push_endpoint = "${google_cloud_run_v2_service.agent.uri}/run"

    oidc_token {
      service_account_email = google_service_account.agent_sa.email
    }
  }

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "300s"
  }

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.events_dlq.id
    max_delivery_attempts = 5
  }

  depends_on = [google_cloud_run_v2_service.agent]
}

# Allow Pub/Sub to invoke the agent Cloud Run service
resource "google_cloud_run_v2_service_iam_member" "pubsub_invoker" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.agent.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.agent_sa.email}"
}
