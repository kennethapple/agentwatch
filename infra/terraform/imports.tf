# imports.tf — brings resources created by bootstrap.sh into Terraform state.
# These blocks are safe to leave in permanently; once a resource is in state
# Terraform ignores the import block on subsequent runs.

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

import {
  id = "projects/boreal-phoenix-405421/databases/(default)"
  to = google_firestore_database.default
}
