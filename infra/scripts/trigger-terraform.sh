#!/usr/bin/env bash
# trigger-terraform.sh
# Pulls latest, touches main.tf to trigger the terraform CI workflow, and pushes.
#
# Usage:
#   ./infra/scripts/trigger-terraform.sh
#   ./infra/scripts/trigger-terraform.sh "optional custom commit message"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$REPO_ROOT"

echo "▶ Pulling latest..."
git pull origin main

echo "▶ Touching main.tf to trigger terraform workflow..."
echo "" >> infra/terraform/main.tf

git add infra/terraform/main.tf
git commit -m "${1:-ci: trigger terraform apply}"

echo "▶ Pushing..."
git push origin main

echo "✅ Done. Watch the run at:"
echo "   https://github.com/kennethapple/agentwatch/actions/workflows/terraform.yml"
