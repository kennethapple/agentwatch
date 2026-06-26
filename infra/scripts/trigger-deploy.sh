#!/usr/bin/env bash
# trigger-deploy.sh
# Triggers a deploy for one or more services by touching a file in each
# service directory and pushing to main.
#
# Usage:
#   ./infra/scripts/trigger-deploy.sh                        # all services
#   ./infra/scripts/trigger-deploy.sh frontend               # frontend only
#   ./infra/scripts/trigger-deploy.sh agent frontend         # agent + frontend
#   ./infra/scripts/trigger-deploy.sh ingest agent frontend  # all three

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$REPO_ROOT"

VALID_SERVICES=("ingest" "agent" "frontend")
SERVICES=()

# Parse args — default to all services if none given
if [[ $# -eq 0 ]]; then
  SERVICES=("${VALID_SERVICES[@]}")
else
  for arg in "$@"; do
    if [[ " ${VALID_SERVICES[*]} " != *" $arg "* ]]; then
      echo "Error: unknown service '$arg'. Valid options: ${VALID_SERVICES[*]}"
      exit 1
    fi
    SERVICES+=("$arg")
  done
fi

echo "▶ Pulling latest..."
git pull origin main

echo "▶ Touching service files to trigger deploy: ${SERVICES[*]}"
for SERVICE in "${SERVICES[@]}"; do
  case $SERVICE in
    ingest)   FILE="services/ingest/src/index.js" ;;
    agent)    FILE="services/agent/src/server.js" ;;
    frontend) FILE="services/frontend/src/app/globals.css" ;;
  esac
  echo "" >> "$FILE"
  git add "$FILE"
  echo "  touched $FILE"
done

git commit -m "ci: trigger deploy for ${SERVICES[*]}"

echo "▶ Pushing..."
git push origin main

echo ""
echo "✅ Deploy triggered for: ${SERVICES[*]}"
echo "   Watch at: https://github.com/kennethapple/agentwatch/actions/workflows/deploy.yml"
