#!/bin/bash

# Script to monitor completion of managers
# Usage: $REPO_DIR/monitor.sh <run_id> [timeout_minutes]

set -e

# Use environment variable or infer repo directory
REPO_DIR="${MULTIAGENT_CODE_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"

RUN_ID="$1"
TIMEOUT_MINUTES="${2:-30}"  # Default 30 minute timeout

if [[ -z "$RUN_ID" ]]; then
    echo "Usage: $0 <run_id> [timeout_minutes]"
    echo "Example: $0 run-1234567890 45"
    exit 1
fi

BASE_DIR="$REPO_DIR/temp/$RUN_ID"

if [[ ! -d "$BASE_DIR" ]]; then
    echo "Error: Run directory $BASE_DIR does not exist"
    exit 1
fi

# Function to create structured failure file
create_failure_file() {
    local task_name="$1"
    local session_id="$2"
    local base_dir="$3"
    local manager_log="$base_dir/responses/${task_name}_manager.json"
    local worker_log="$base_dir/responses/${task_name}_worker.json"
    
    local failure_file="$base_dir/FAILURE"
    
    cat > "$failure_file" << EOF
{
  "failed_task": "$task_name",
  "session_id": "$session_id",
  "manager_log": "responses/${task_name}_manager.json",
  "worker_log": "responses/${task_name}_worker.json",
  "resume_command": "claude --resume \"$session_id\" -p \"retry with corrections\" --dangerously-skip-permissions >> \"$worker_log\" 2>&1",
  "timestamp": "$(date -Iseconds)"
}
EOF
    
    echo "❌ FAILURE FILE CREATED: $failure_file"
    echo "Task: $task_name"
    echo "Session: $session_id"
    echo "To resume: claude --resume \"$session_id\" -p \"your corrections\" --dangerously-skip-permissions >> \"$worker_log\" 2>&1"
}

# Function to process a completed task
process_completed_task() {
    local task_name="$1"
    local base_dir="$2"
    local manager_log="$base_dir/responses/${task_name}_manager.json"
    local worker_log="$base_dir/responses/${task_name}_worker.json"

    echo "Checking manager log: $manager_log"
    
    # Check for exact status strings from manager
    if grep -q "ORCHESTRATOR_STATUS: SUCCESS" "$manager_log" 2>/dev/null; then
        echo "✅ $task_name: SUCCESS"
        return 0
    elif grep -q "ORCHESTRATOR_STATUS: FAILURE" "$manager_log" 2>/dev/null; then
        echo "❌ $task_name: FAILED - STOPPING MONITOR"
        handle_failed_task "$task_name" "$base_dir"
        return 1
    else
        echo "❌ $task_name: NO STATUS FOUND - searching for status in file..."
        echo "File contents (last 5 lines):"
        tail -5 "$manager_log" 2>/dev/null || echo "Could not read file"
        handle_failed_task "$task_name" "$base_dir"
        return 1
    fi
}

# Function to handle failed tasks
handle_failed_task() {
    local task_name="$1"
    local base_dir="$2"
    local manager_log="$base_dir/responses/${task_name}_manager.json"
    local worker_log="$base_dir/responses/${task_name}_worker.json"

    # Extract session ID from worker log first (more detailed), then manager log
    local session_id=""
    if [[ -f "$worker_log" ]]; then
        session_id=$(grep -o '"session_id":"[^"]*"' "$worker_log" 2>/dev/null | tail -1 | cut -d'"' -f4)
    fi
    if [[ -z "$session_id" && -f "$manager_log" ]]; then
        session_id=$(grep -o '"session_id":"[^"]*"' "$manager_log" 2>/dev/null | tail -1 | cut -d'"' -f4)
    fi

    # Create structured failure file for agent recovery
    create_failure_file "$task_name" "$session_id" "$base_dir"
    
    # Also log to failures.log for backwards compatibility
    echo "$task_name: FAILED at $(date) - Manager: $manager_log, Worker: $worker_log" >> "$base_dir/failures.log"
    
    # Exit immediately for AI agent
    exit 1
}

# Main monitoring function
monitor_completion() {
    local run_id="$1"
    local timeout_minutes="$2"
    local base_dir="$REPO_DIR/temp/$run_id"

    # Read process info
    if [[ ! -f "$base_dir/pids.txt" ]]; then
        echo "Error: No process info found. Run launch_managers.sh first."
        exit 1
    fi

    read -a pids < "$base_dir/pids.txt"
    read -a tasks < "$base_dir/tasks.txt"
    local total=$(cat "$base_dir/total.txt")

    local completed=0
    local checked=()
    local start_time=$(date +%s)

    # Check for existing failure file - agent must clean it up before restarting
    if [[ -f "$base_dir/FAILURE" ]]; then
        echo "❌ PREVIOUS FAILURE DETECTED"
        echo "A previous failure must be resolved before monitoring can continue."
        echo "Failure details: $base_dir/FAILURE"
        echo ""
        cat "$base_dir/FAILURE"
        echo ""
        echo "After resolving the failure, delete the FAILURE file and restart monitoring."
        exit 1
    fi

    echo "Monitoring $total managers with ${timeout_minutes}m timeout..."
    echo "Started at: $(date)"
    echo ""

    # Initial scan for already completed tasks
    echo "Scanning for completed tasks..."
    for i in "${!pids[@]}"; do
        local pid="${pids[$i]}"
        local task="${tasks[$i]}"
        
        echo "Checking task: $task (PID: $pid)"

        # Check if process is no longer running or is zombie (completed)
        if ! kill -0 "$pid" 2>/dev/null; then
            echo "Process $pid is dead - checking completion status for $task"
            if ! process_completed_task "$task" "$base_dir"; then
                # Failed task detected during initial scan - exit immediately
                exit 1
            fi
            checked+=("$task")
            ((completed++))
        elif ps -p "$pid" -o stat= 2>/dev/null | grep -q "Z"; then
            echo "Process $pid is zombie (completed) - checking completion status for $task"
            if ! process_completed_task "$task" "$base_dir"; then
                # Failed task detected during initial scan - exit immediately
                exit 1
            fi
            checked+=("$task")
            ((completed++))
        else
            echo "Process $pid is still running"
        fi
    done

    if [ $completed -gt 0 ]; then
        echo "Initial scan complete: $completed/$total already finished"
        echo ""
    fi

    while [ $completed -lt $total ]; do
        local current_time=$(date +%s)
        local elapsed=$(( (current_time - start_time) / 60 ))

        # Check for timeout
        if [ $elapsed -ge $timeout_minutes ]; then
            echo "TIMEOUT: ${timeout_minutes} minutes exceeded. Killing remaining processes..."
            for pid in "${pids[@]}"; do
                if kill -0 "$pid" 2>/dev/null; then
                    echo "Killing hung process: $pid"
                    kill -9 "$pid" 2>/dev/null
                fi
            done
            break
        fi

        for i in "${!pids[@]}"; do
            local pid="${pids[$i]}"
            local task="${tasks[$i]}"

            # Skip already processed tasks
            [[ " ${checked[@]} " =~ " ${task} " ]] && continue

            # Check if process is still running or zombie
            if ! kill -0 "$pid" 2>/dev/null; then
                echo "Manager '$task' completed (PID: $pid)"

                # Process the completed task immediately
                if ! process_completed_task "$task" "$base_dir"; then
                    # Failed task detected - exit immediately
                    exit 1
                fi

                checked+=("$task")
                ((completed++))

                echo "Progress: $completed/$total completed"
                echo ""
            elif ps -p "$pid" -o stat= 2>/dev/null | grep -q "Z"; then
                echo "Manager '$task' zombie (completed) (PID: $pid)"

                # Process the completed task immediately
                if ! process_completed_task "$task" "$base_dir"; then
                    # Failed task detected - exit immediately
                    exit 1
                fi

                checked+=("$task")
                ((completed++))

                echo "Progress: $completed/$total completed"
                echo ""
            fi
        done

        # Brief pause to avoid excessive polling
        sleep 3
    done

    echo "Monitoring complete! $completed/$total tasks finished."
    echo "Completed at: $(date)"
    
    # Show summary
    echo ""
    echo "=== SUMMARY ==="
    if [[ -f "$base_dir/failures.log" ]]; then
        echo "❌ Failed tasks:"
        cat "$base_dir/failures.log"
    else
        echo "✅ All tasks completed successfully!"
    fi
}

# Start monitoring
monitor_completion "$RUN_ID" "$TIMEOUT_MINUTES"