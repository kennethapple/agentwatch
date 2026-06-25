# Dead-letter topic
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
# We use a local to build the push endpoint URL rather than referencing
# the Cloud Run service directly, which would create a circular dependency
# (Cloud Run needs Pub/Sub topic; Pub/Sub sub needs Cloud Run URL).
# On first apply the subscription is created with the placeholder image URL;
# subsequent applies update it once the real URL is known.
locals {
  agent_run_url = "${google_cloud_run_v2_service.agent.uri}/run"
}

resource "google_pubsub_subscription" "agent_sub" {
  name    = "agentwatch-agent-sub"
  topic   = google_pubsub_topic.events.name
  project = var.project_id

  # Extend ack deadline to give the agent time to start processing
  ack_deadline_seconds = 60

  push_config {
    push_endpoint = local.agent_run_url

    oidc_token {
      service_account_email = google_service_account.agent_sa.email
      audience              = local.agent_run_url
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

  # Pub/Sub SA needs token creator role before this can be created
  depends_on = [
    google_project_iam_member.pubsub_token_creator,
    google_cloud_run_v2_service.agent,
  ]
}

# Allow Pub/Sub to invoke the agent Cloud Run service
resource "google_cloud_run_v2_service_iam_member" "pubsub_invoker" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.agent.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.agent_sa.email}"
}
