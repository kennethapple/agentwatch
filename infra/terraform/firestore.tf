resource "google_firestore_database" "default" {
  project     = var.project_id
  name        = "(default)"
  location_id = var.region
  type        = "FIRESTORE_NATIVE"

  depends_on = [google_project_service.apis]
}

# Composite index for querying runs by eventId + createdAt
resource "google_firestore_index" "runs_by_event" {
  project    = var.project_id
  database   = google_firestore_database.default.name
  collection = "runs"

  fields {
    field_path = "eventId"
    order      = "ASCENDING"
  }
  fields {
    field_path = "createdAt"
    order      = "DESCENDING"
  }
}

# Composite index for querying events by source + receivedAt
resource "google_firestore_index" "events_by_source" {
  project    = var.project_id
  database   = google_firestore_database.default.name
  collection = "events"

  fields {
    field_path = "source"
    order      = "ASCENDING"
  }
  fields {
    field_path = "receivedAt"
    order      = "DESCENDING"
  }
}
