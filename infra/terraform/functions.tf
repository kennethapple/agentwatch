resource "google_storage_bucket" "functions_source" {
  name                        = "${var.project_id}-agentwatch-functions-src"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = true

  depends_on = [google_project_service.apis]
}

data "archive_file" "ingest_source" {
  type        = "zip"
  source_dir  = "${path.module}/../../services/ingest"
  output_path = "/tmp/ingest-source.zip"
  excludes    = ["node_modules", ".env", "*.test.js", "fixtures", "scripts"]
}

resource "google_storage_bucket_object" "ingest_source" {
  name   = "ingest-${data.archive_file.ingest_source.output_md5}.zip"
  bucket = google_storage_bucket.functions_source.name
  source = data.archive_file.ingest_source.output_path
}

# ── Gmail ingest function ─────────────────────────────────────────────────────
resource "google_cloudfunctions2_function" "ingest_gmail" {
  name     = "agentwatch-ingest-gmail"
  location = var.region
  project  = var.project_id

  build_config {
    runtime     = "nodejs20"
    entry_point = "gmailHandler"
    source {
      storage_source {
        bucket = google_storage_bucket.functions_source.name
        object = google_storage_bucket_object.ingest_source.name
      }
    }
  }

  service_config {
    available_memory      = "256M"
    timeout_seconds       = 30
    service_account_email = google_service_account.ingest_sa.email

    environment_variables = {
      GCP_PROJECT_ID = var.project_id
      PUBSUB_TOPIC   = google_pubsub_topic.events.name
    }

    secret_environment_variables {
      key        = "GMAIL_WEBHOOK_TOKEN"
      project_id = var.project_id
      secret     = google_secret_manager_secret.gmail_webhook_token.secret_id
      version    = "latest"
    }
  }

  depends_on = [
    google_project_service.apis,
    google_storage_bucket_object.ingest_source,
  ]
}

# Cloud Functions v2 uses cloudfunctions2_function_iam_member, not cloud_run_service_iam_member
resource "google_cloudfunctions2_function_iam_member" "ingest_gmail_public" {
  project        = var.project_id
  location       = var.region
  cloud_function = google_cloudfunctions2_function.ingest_gmail.name
  role           = "roles/cloudfunctions.invoker"
  member         = "allUsers"
}

# ── Slack ingest function ─────────────────────────────────────────────────────
resource "google_cloudfunctions2_function" "ingest_slack" {
  name     = "agentwatch-ingest-slack"
  location = var.region
  project  = var.project_id

  build_config {
    runtime     = "nodejs20"
    entry_point = "slackHandler"
    source {
      storage_source {
        bucket = google_storage_bucket.functions_source.name
        object = google_storage_bucket_object.ingest_source.name
      }
    }
  }

  service_config {
    available_memory      = "256M"
    timeout_seconds       = 30
    service_account_email = google_service_account.ingest_sa.email

    environment_variables = {
      GCP_PROJECT_ID = var.project_id
      PUBSUB_TOPIC   = google_pubsub_topic.events.name
    }

    secret_environment_variables {
      key        = "SLACK_SIGNING_SECRET"
      project_id = var.project_id
      secret     = google_secret_manager_secret.slack_signing_secret.secret_id
      version    = "latest"
    }
  }

  depends_on = [
    google_project_service.apis,
    google_storage_bucket_object.ingest_source,
  ]
}

resource "google_cloudfunctions2_function_iam_member" "ingest_slack_public" {
  project        = var.project_id
  location       = var.region
  cloud_function = google_cloudfunctions2_function.ingest_slack.name
  role           = "roles/cloudfunctions.invoker"
  member         = "allUsers"
}
