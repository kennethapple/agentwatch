# imports.tf — brings resources created by bootstrap.sh into Terraform state.
# Native import blocks (Terraform 1.5+) are idempotent — once a resource is
# in state these blocks are silently ignored on subsequent runs.

import {
  id = "projects/boreal-phoenix-405421/locations/global/workloadIdentityPools/agentwatch-gh-pool"
  to = google_iam_workload_identity_pool.github
}

import {
  id = "projects/boreal-phoenix-405421/locations/global/workloadIdentityPools/agentwatch-gh-pool/providers/agentwatch-gh-provider"
  to = google_iam_workload_identity_pool_provider.github
}

import {
  id = "projects/boreal-phoenix-405421/serviceAccounts/agentwatch-deploy-sa@boreal-phoenix-405421.iam.gserviceaccount.com"
  to = google_service_account.deploy_sa
}

# Firestore database ID format: just the database name, not the full path
import {
  id = "(default)"
  to = google_firestore_database.default
}
