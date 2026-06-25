variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for all resources"
  type        = string
  default     = "us-central1"
}

variable "anthropic_api_key" {
  description = "Anthropic API key for the agent service"
  type        = string
  sensitive   = true
}

variable "slack_signing_secret" {
  description = "Slack app signing secret for request validation"
  type        = string
  sensitive   = true
}

variable "gmail_webhook_token" {
  description = "Token used to validate Gmail Pub/Sub push notifications"
  type        = string
  sensitive   = true
}

variable "agent_image" {
  description = "Container image for the agent Cloud Run service"
  type        = string
  default     = "gcr.io/cloudrun/placeholder"  # overridden by CI/CD
}

variable "frontend_image" {
  description = "Container image for the frontend Cloud Run service"
  type        = string
  default     = "gcr.io/cloudrun/placeholder"
}
