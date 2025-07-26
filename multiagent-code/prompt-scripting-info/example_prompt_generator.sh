#!/bin/bash

# Example: Generate prompts for cleaning up multiple files
# Usage: claude-orchestrator/example_prompt_generator.sh <run_id> <file1> <file2> ...

set -e  # Exit on any error

RUN_ID="$1"
shift  # Remove first argument, rest are files

if [[ -z "$RUN_ID" ]]; then
    echo "Usage: $0 <run_id> <file1> <file2> ..."
    echo "Example: $0 run-123 src/auth.js src/api.ts utils/helpers.py"
    exit 1
fi

BASE_DIR="claude-orchestrator/temp/$RUN_ID"

if [[ ! -d "$BASE_DIR" ]]; then
    echo "Error: Run directory $BASE_DIR does not exist"
    echo "Run: claude-orchestrator/setup_run.sh first"
    exit 1
fi

# Generate a prompt for each file
COUNTER=1
for file in "$@"; do
    # Extract filename without path and extension for task naming
    filename=$(basename "$file")
    task_name="cleanup_${COUNTER}_${filename}"
    
    # Validate the file exists (optional check)
    if [[ ! -f "$file" ]]; then
        echo "Warning: File $file does not exist, but creating prompt anyway"
    fi
    
    cat > "$BASE_DIR/prompts/${task_name}.md" << EOF
# Task: Clean up and optimize $file

Please review and clean up the file \`$file\` to improve code quality, readability, and maintainability.

## Requirements:

- Remove dead code and unused imports
- Fix formatting and ensure consistent indentation
- Add proper JSDoc/docstring comments for functions
- Optimize performance where applicable
- Ensure consistent naming conventions
- Fix any obvious bugs or issues
- Follow language-specific best practices

## Success Criteria:

- Code compiles/runs without errors
- All functionality is preserved
- Code is more readable and maintainable
- Follows project conventions

The cleaned file should be ready for production use with improved maintainability.
EOF

    echo "Generated prompt: ${task_name}.md for file: $file"
    ((COUNTER++))
done

echo ""
echo "Generated $((COUNTER-1)) prompt files in $BASE_DIR/prompts/"
echo "Next steps:"
echo "  claude-orchestrator/launch_managers.sh $RUN_ID"
echo "  claude-orchestrator/monitor.sh $RUN_ID"