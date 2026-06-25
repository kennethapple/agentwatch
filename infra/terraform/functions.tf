locals {
  ingest_source_dir = "${path.module}/../../services/ingest"
}

resource "google_storage_bucket" "functions_source" {
  name                        = "${var.project_id}-agentwatch-functions-src"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = true
}

data "archive_file" "ingest_source" {
  type        = "zip"
  source_dir  = local.ingest_source_dir
  output_path = "/tmp/ingest-source.zip"
  excludes    = ["node_modules", ".env", "*.test.js"]
}

resource "google_storage_bucket_object" "ingest_source" {
  name   = "ingest-${data.archive_file.ingest_source.output_md5}.zip"
  bucket = google_storage_bucket.functions_source.name
  source = data.archive_file.ingest_source.output_path
}

# Gmail ingest function
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

  depends_on = [google_project_service.apis]
}

resource "google_cloud_run_service_iam_member" "ingest_gmail_public" {
  project  = var.project_id
  location = var.region
  service  = google_cloudfunctions2_function.ingest_gmail.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Slack ingest function
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

  depends_on = [google_project_service.apis]
}

resource "google_cloud_run_service_iam_member" "ingest_slack_public" {
  project  = var.project_id
  location = var.region
  service  = google_cloudfunctions2_function.ingest_slack.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
