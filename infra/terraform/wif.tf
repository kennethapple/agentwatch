# ── Workload Identity Federation ─────────────────────────────────────────────
# Allows GitHub Actions to authenticate to GCP without a service account key.
# The bootstrap.sh script creates the pool/provider; Terraform manages them
# as well so they are tracked in state.

data "google_project" "project" {
  project_id = var.project_id
}

resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "agentwatch-gh-pool"
  display_name              = "AgentWatch GitHub Actions"
  project                   = var.project_id

  depends_on = [google_project_service.apis]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "agentwatch-gh-provider"
  project                            = var.project_id
  display_name                       = "GitHub OIDC"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
  }

  attribute_condition = "assertion.repository=='${var.github_repo}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# ── Deploy service account ────────────────────────────────────────────────────
resource "google_service_account" "deploy_sa" {
  account_id   = "agentwatch-deploy-sa"
  display_name = "AgentWatch GitHub Deploy"
  project      = var.project_id
}

# Allow GitHub Actions (via WIF) to impersonate the deploy SA
resource "google_service_account_iam_member" "wif_binding" {
  service_account_id = google_service_account.deploy_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repo}"
}

# Roles the deploy SA needs to run terraform apply and deploy services
locals {
  deploy_roles = [
    "roles/run.admin",
    "roles/cloudfunctions.admin",
    "roles/pubsub.admin",
    "roles/datastore.owner",
    "roles/secretmanager.admin",
    "roles/artifactregistry.admin",
    "roles/iam.serviceAccountUser",
    "roles/storage.admin",
    "roles/serviceusage.serviceUsageAdmin",
    "roles/resourcemanager.projectIamAdmin",
  ]
}

resource "google_project_iam_member" "deploy_sa_roles" {
  for_each = toset(local.deploy_roles)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.deploy_sa.email}"
}
