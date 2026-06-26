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
  excludes    = [".env", "*.test.js", "fixtures", "scripts", "node_modules"]
}

resource "google_storage_bucket_object" "ingest_source" {
  name   = "ingest-${data.archive_file.ingest_source.output_md5}.zip"
  bucket = google_storage_bucket.functions_source.name
  source = data.archive_file.ingest_source.output_path
}

# ── Slack ingest function ─────────────────────────────────────────────────────
# Deployed first so Gmail can depend on it — GCP rejects concurrent
# function updates in the same project with "unable to queue the operation".
resource "google_cloudfunctions2_function" "ingest_slack" {
  name     = "agentwatch-ingest-slack"
  location = var.region
  project  = var.project_id

  build_config {
    runtime     = "nodejs22"
    entry_point = "slackHandler"
    # Cloud Functions v2 runs npm install during build.
    # node_modules must NOT be in the zip.
    source {
      storage_source {
        bucket = google_storage_bucket.functions_source.name
        object = google_storage_bucket_object.ingest_source.name
      }
    }
  }

  service_config {
    available_memory                 = "256M"
    timeout_seconds                  = 30
    max_instance_count               = 10
    min_instance_count               = 0
    max_instance_request_concurrency = 1
    service_account_email            = google_service_account.ingest_sa.email

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
    # SA must have secret access before the function starts
    google_secret_manager_secret_iam_member.ingest_slack,
    # Secret value must exist before the function mounts it
    google_secret_manager_secret_version.slack_signing_secret,
  ]
}

resource "google_cloudfunctions2_function_iam_member" "ingest_slack_public" {
  project        = var.project_id
  location       = var.region
  cloud_function = google_cloudfunctions2_function.ingest_slack.name
  role           = "roles/cloudfunctions.invoker"
  member         = "allUsers"
}

# ── Gmail ingest function ─────────────────────────────────────────────────────
# Deployed after Slack to avoid GCP concurrent-update 409 errors.
resource "google_cloudfunctions2_function" "ingest_gmail" {
  name     = "agentwatch-ingest-gmail"
  location = var.region
  project  = var.project_id

  build_config {
    runtime     = "nodejs22"
    entry_point = "gmailHandler"
    source {
      storage_source {
        bucket = google_storage_bucket.functions_source.name
        object = google_storage_bucket_object.ingest_source.name
      }
    }
  }

  service_config {
    available_memory                 = "256M"
    timeout_seconds                  = 30
    max_instance_count               = 10
    min_instance_count               = 0
    max_instance_request_concurrency = 1
    service_account_email            = google_service_account.ingest_sa.email

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
    # Must come after Slack to avoid GCP concurrent-update 409
    google_cloudfunctions2_function.ingest_slack,
    # SA must have secret access before the function starts
    google_secret_manager_secret_iam_member.ingest_gmail,
    # Secret value must exist before the function mounts it
    google_secret_manager_secret_version.gmail_webhook_token,
  ]
}

resource "google_cloudfunctions2_function_iam_member" "ingest_gmail_public" {
  project        = var.project_id
  location       = var.region
  cloud_function = google_cloudfunctions2_function.ingest_gmail.name
  role           = "roles/cloudfunctions.invoker"
  member         = "allUsers"
}
