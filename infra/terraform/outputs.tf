output "agent_url" {
  description = "Cloud Run agent service URL"
  value       = google_cloud_run_v2_service.agent.uri
}

output "frontend_url" {
  description = "Cloud Run frontend service URL"
  value       = google_cloud_run_v2_service.frontend.uri
}

output "ingest_gmail_url" {
  description = "Gmail webhook URL — register this with gmail.users.watch"
  value       = google_cloudfunctions2_function.ingest_gmail.service_config[0].uri
}

output "ingest_slack_url" {
  description = "Slack webhook URL — register this in your Slack app Event Subscriptions"
  value       = google_cloudfunctions2_function.ingest_slack.service_config[0].uri
}

output "events_topic" {
  description = "Pub/Sub events topic name"
  value       = google_pubsub_topic.events.name
}
