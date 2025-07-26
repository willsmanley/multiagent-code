#!/bin/bash

# Script to launch managers for all prompts in a run directory
# Usage: $MULTIAGENT_CODE_DIR/launch_managers.sh <run_id>

set -e

# Use provided environment variable or infer repo directory
REPO_DIR="${MULTIAGENT_CODE_DIR:-$(cd "$(dirname "$0")" && pwd)}"

RUN_ID="$1"

if [[ -z "$RUN_ID" ]]; then
    echo "Usage: $0 <run_id>"
    echo "Example: $0 run-1234567890"
    exit 1
fi

BASE_DIR="$REPO_DIR/temp/$RUN_ID"

if [[ ! -d "$BASE_DIR" ]]; then
    echo "Error: Run directory $BASE_DIR does not exist"
    exit 1
fi

if [[ ! -d "$BASE_DIR/prompts" ]]; then
    echo "Error: Prompts directory $BASE_DIR/prompts does not exist"
    exit 1
fi

# Arrays to track processes
declare -a PIDS=()
declare -a TASKS=()

# Function to launch a single manager
launch_manager() {
    local task_name="$1"
    local prompt_file="$2"
    
    # Pre-determine the log file paths
    local manager_log="$BASE_DIR/responses/${task_name}_manager.json"
    local worker_log="$BASE_DIR/responses/${task_name}_worker.json"

    echo "Launching manager for $task_name..."
    echo "  Manager log: $manager_log"
    echo "  Worker log: $worker_log"
    
    # Create the enhanced prompt with log paths
    local enhanced_prompt="MANAGER_LOG_PATH: $manager_log
WORKER_LOG_PATH: $worker_log

$(cat "$REPO_DIR/manager.md")

prompt file: $prompt_file"
    
    claude -p "$enhanced_prompt" --dangerously-skip-permissions --output-format json --verbose >> "$manager_log" 2>&1 & local pid=$!
    PIDS+=($pid)
    TASKS+=("$task_name")

    echo "  → PID: $pid"
}

echo "Launching managers for run: $RUN_ID"
echo "Base directory: $BASE_DIR"

# Launch managers for all prompt files
for prompt_file in "$BASE_DIR/prompts"/*.md; do
    if [[ -f "$prompt_file" ]]; then
        # Extract task name from filename (remove path and .md extension)
        task_name=$(basename "$prompt_file" .md)
        launch_manager "$task_name" "$prompt_file"
    fi
done

# Save process info for monitoring
echo "${PIDS[@]}" > "$BASE_DIR/pids.txt"
echo "${TASKS[@]}" > "$BASE_DIR/tasks.txt"
echo "${#PIDS[@]}" > "$BASE_DIR/total.txt"

echo ""
echo "Launched ${#PIDS[@]} managers successfully!"
echo "Process IDs saved to: $BASE_DIR/pids.txt"
echo "Task names saved to: $BASE_DIR/tasks.txt"
echo ""
echo "To monitor progress, run:"
echo "  $REPO_DIR/monitor.sh $RUN_ID"