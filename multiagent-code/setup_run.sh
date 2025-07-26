#!/bin/bash

# Simple script to create run directory structure
# Usage: $REPO_DIR/setup_run.sh [custom_run_id]

RUN_ID="${1:-run-$(date +%s)}"
REPO_DIR="${MULTIAGENT_CODE_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
BASE_DIR="$REPO_DIR/temp/$RUN_ID"

mkdir -p "$BASE_DIR/prompts" "$BASE_DIR/responses" "$BASE_DIR/scripts" "$BASE_DIR/misc"

echo "$RUN_ID" > "$BASE_DIR/run_id.txt"
echo "Created run directory: $BASE_DIR"
echo "Run ID: $RUN_ID"
echo ""
echo "Next steps:"
echo "1. Create your prompt files in: $BASE_DIR/prompts/"
echo "2. Launch managers: $REPO_DIR/launch_managers.sh $RUN_ID"
echo "3. Monitor progress: $REPO_DIR/monitor.sh $RUN_ID"