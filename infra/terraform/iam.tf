# Ingest service account (Cloud Functions)
resource "google_service_account" "ingest_sa" {
  account_id   = "agentwatch-ingest-sa"
  display_name = "AgentWatch Ingest"
  project      = var.project_id
}

resource "google_project_iam_member" "ingest_pubsub_publisher" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.ingest_sa.email}"
}

resource "google_project_iam_member" "ingest_firestore_writer" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.ingest_sa.email}"
}

# Agent service account (Cloud Run)
resource "google_service_account" "agent_sa" {
  account_id   = "agentwatch-agent-sa"
  display_name = "AgentWatch Agent"
  project      = var.project_id
}

resource "google_project_iam_member" "agent_firestore_writer" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.agent_sa.email}"
}

resource "google_project_iam_member" "agent_pubsub_subscriber" {
  project = var.project_id
  role    = "roles/pubsub.subscriber"
  member  = "serviceAccount:${google_service_account.agent_sa.email}"
}

# Frontend service account (Cloud Run)
resource "google_service_account" "frontend_sa" {
  account_id   = "agentwatch-frontend-sa"
  display_name = "AgentWatch Frontend"
  project      = var.project_id
}

resource "google_project_iam_member" "frontend_firestore_reader" {
  project = var.project_id
  role    = "roles/datastore.viewer"
  member  = "serviceAccount:${google_service_account.frontend_sa.email}"
}
