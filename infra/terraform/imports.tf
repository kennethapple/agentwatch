# imports.tf — documents resources that were created by bootstrap.sh
# and imported into Terraform state via the terraform.yml CI workflow.
#
# The actual imports are handled by `terraform import` commands in
# .github/workflows/terraform.yml before each apply, using || true
# so they are idempotent (no-op if already in state).
#
# Resources managed this way:
#   - google_iam_workload_identity_pool.github
#   - google_iam_workload_identity_pool_provider.github
#   - google_service_account.deploy_sa
#   - google_firestore_database.default
