# Firestore database is intentionally NOT managed by Terraform.
#
# Reasons:
# 1. GCP does not allow deleting Firestore databases once created, so
#    Terraform can never fully manage the lifecycle.
# 2. The database was created before Terraform ran and cannot be cleanly
#    imported without manual intervention.
#
# The database was created manually via bootstrap.sh or gcloud:
#   gcloud firestore databases create \
#     --location=us-central1 \
#     --project=boreal-phoenix-405421
#
# Indexes are managed separately below since they can be safely
# created and deleted by Terraform.

resource "google_firestore_index" "runs_by_event" {
  project    = var.project_id
  database   = "(default)"
  collection = "runs"

  fields {
    field_path = "eventId"
    order      = "ASCENDING"
  }
  fields {
    field_path = "createdAt"
    order      = "DESCENDING"
  }

  depends_on = [google_project_service.apis]
}

resource "google_firestore_index" "events_by_source" {
  project    = var.project_id
  database   = "(default)"
  collection = "events"

  fields {
    field_path = "source"
    order      = "ASCENDING"
  }
  fields {
    field_path = "receivedAt"
    order      = "DESCENDING"
  }

  depends_on = [google_project_service.apis]
}
