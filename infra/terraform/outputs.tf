output "agent_url" {
  description = "Cloud Run agent service URL"
  value       = google_cloud_run_v2_service.agent.uri
}

output "frontend_url" {
  description = "Cloud Run frontend URL — open this in your browser"
  value       = google_cloud_run_v2_service.frontend.uri
}

output "ingest_gmail_url" {
  description = "Gmail webhook URL — pass to gmail.users.watch as pushConfig.topicName"
  value       = google_cloudfunctions2_function.ingest_gmail.service_config[0].uri
}

output "ingest_slack_url" {
  description = "Slack Events API request URL — paste into your Slack app settings"
  value       = google_cloudfunctions2_function.ingest_slack.service_config[0].uri
}

output "events_topic" {
  description = "Pub/Sub events topic name"
  value       = google_pubsub_topic.events.name
}

output "artifact_registry" {
  description = "Artifact Registry repo for container images"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/agentwatch"
}

output "wif_provider" {
  description = "Workload Identity Provider — set as GCP_WORKLOAD_IDENTITY_PROVIDER in GitHub Actions secrets"
  value       = "projects/${data.google_project.project.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github.workload_identity_pool_id}/providers/${google_iam_workload_identity_pool_provider.github.workload_identity_pool_provider_id}"
}

output "deploy_sa" {
  description = "Deploy service account email — set as GCP_DEPLOY_SA in GitHub Actions secrets"
  value       = google_service_account.deploy_sa.email
}
