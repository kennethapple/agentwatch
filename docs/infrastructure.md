# Infrastructure

All GCP resources are managed with Terraform in `infra/terraform/`.

## Resources provisioned

| Resource | Name | Purpose |
|---|---|---|
| Pub/Sub topic | `agentwatch-events` | Main event queue |
| Pub/Sub topic | `agentwatch-events-dlq` | Dead-letter queue |
| Pub/Sub subscription | `agentwatch-agent-sub` | Push sub → agent Cloud Run |
| Firestore database | `(default)` | Event log + run steps |
| Cloud Run service | `agentwatch-agent` | Agent runtime |
| Cloud Run service | `agentwatch-frontend` | Next.js UI |
| Cloud Functions | `agentwatch-ingest-gmail` | Gmail webhook |
| Cloud Functions | `agentwatch-ingest-slack` | Slack webhook |
| Secret Manager secrets | see architecture.md | All credentials |
| Service accounts | `agentwatch-ingest-sa`, `agentwatch-agent-sa` | Least-privilege IAM |
| Artifact Registry | `agentwatch` | Container images |

## Applying

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your project_id, region, etc.
terraform init
terraform plan
terraform apply
```

## State backend

Remote state is stored in a GCS bucket. The bucket must exist before `terraform init`:

```bash
gsutil mb -p YOUR_PROJECT gs://YOUR_PROJECT-tfstate
```

Then set in `backend.tf`:
```hcl
terraform {
  backend "gcs" {
    bucket = "YOUR_PROJECT-tfstate"
    prefix = "agentwatch"
  }
}
```

## Destroying

```bash
terraform destroy
```

Note: Firestore databases cannot be deleted via Terraform once they contain data. Delete manually via console if needed.
