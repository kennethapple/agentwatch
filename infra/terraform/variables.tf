variable "project_id" {
  description = "GCP project ID"
  type        = string
  default     = "boreal-phoenix-405421"
}

variable "region" {
  description = "GCP region for all resources"
  type        = string
  default     = "us-central1"
}

variable "github_repo" {
  description = "GitHub repo in owner/name format — used for Workload Identity Federation"
  type        = string
  default     = "kennethapple/agentwatch"
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
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}

variable "frontend_image" {
  description = "Container image for the frontend Cloud Run service"
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}
