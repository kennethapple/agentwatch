resource "google_secret_manager_secret" "anthropic_api_key" {
  secret_id = "anthropic-api-key"
  project   = var.project_id

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "anthropic_api_key" {
  secret      = google_secret_manager_secret.anthropic_api_key.id
  secret_data = var.anthropic_api_key
}

resource "google_secret_manager_secret" "slack_signing_secret" {
  secret_id = "slack-signing-secret"
  project   = var.project_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "slack_signing_secret" {
  secret      = google_secret_manager_secret.slack_signing_secret.id
  secret_data = var.slack_signing_secret
}

resource "google_secret_manager_secret" "gmail_webhook_token" {
  secret_id = "gmail-webhook-token"
  project   = var.project_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "gmail_webhook_token" {
  secret      = google_secret_manager_secret.gmail_webhook_token.id
  secret_data = var.gmail_webhook_token
}

# Grant ingest SA access to its secrets
resource "google_secret_manager_secret_iam_member" "ingest_slack" {
  secret_id = google_secret_manager_secret.slack_signing_secret.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.ingest_sa.email}"
}

resource "google_secret_manager_secret_iam_member" "ingest_gmail" {
  secret_id = google_secret_manager_secret.gmail_webhook_token.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.ingest_sa.email}"
}

# Grant agent SA access to Anthropic key
resource "google_secret_manager_secret_iam_member" "agent_anthropic" {
  secret_id = google_secret_manager_secret.anthropic_api_key.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.agent_sa.email}"
}
