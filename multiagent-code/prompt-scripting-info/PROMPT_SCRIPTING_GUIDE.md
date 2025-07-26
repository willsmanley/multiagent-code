# Prompt Generation Scripting Guide

When you need to create many similar prompts with small variations, write a script to generate them instead of doing it manually.

## Basic Template

```bash
#!/bin/bash
set -e  # Exit on any error

RUN_ID="$1"
shift  # Remove first argument, rest are your parameters

if [[ -z "$RUN_ID" ]]; then
    echo "Usage: $0 <run_id> <your_params...>"
    exit 1
fi

BASE_DIR="claude-orchestrator/temp/$RUN_ID"

if [[ ! -d "$BASE_DIR" ]]; then
    echo "Error: Run directory $BASE_DIR does not exist"
    exit 1
fi

# Your prompt generation logic here
COUNTER=1
for item in "$@"; do
    task_name="task_${COUNTER}_${item}"

    cat > "$BASE_DIR/prompts/${task_name}.md" << EOF
# Task: Do something with $item

[Your prompt content here]

## Requirements:
- Specific requirement 1
- Specific requirement 2

The output should...
EOF

    echo "Generated: ${task_name}.md"
    ((COUNTER++))
done
```

## Example 1: File Cleanup (Simple)

```bash
#!/bin/bash
# Usage: ./cleanup_generator.sh <run_id> <file1> <file2> ...

set -e
RUN_ID="$1" && shift
BASE_DIR="claude-orchestrator/temp/$RUN_ID"

COUNTER=1
for file in "$@"; do
    task_name="cleanup_${COUNTER}_$(basename "$file")"

    cat > "$BASE_DIR/prompts/${task_name}.md" << EOF
# Task: Clean up $file

Clean up and optimize \`$file\` for better code quality.

## Requirements:
- Remove dead code and unused imports
- Fix formatting and indentation
- Add proper comments
- Follow best practices

The file should be production-ready.
EOF

    ((COUNTER++))
done
```

## Example 2: Component Creation (Array-based)

```bash
#!/bin/bash
# Usage: ./component_generator.sh <run_id>

set -e
RUN_ID="$1"
BASE_DIR="claude-orchestrator/temp/$RUN_ID"

# Define components to create
declare -a components=(
    "UserProfile:Display user information and avatar"
    "SearchBar:Handle search input with autocomplete"
    "NotificationPanel:Show real-time notifications"
    "Settings:Manage user preferences"
)

for component_def in "${components[@]}"; do
    IFS=':' read -r name description <<< "$component_def"

    cat > "$BASE_DIR/prompts/component_${name}.md" << EOF
# Task: Create $name component

Create a React component for $description.

## Requirements:
- Use TypeScript
- Include proper prop types
- Add error handling
- Follow existing component patterns
- Include basic styling

The component should be reusable and well-documented.
EOF

    echo "Generated: component_${name}.md"
done
```

## Example 3: API Endpoint Testing

```bash
#!/bin/bash
# Usage: ./api_test_generator.sh <run_id> <endpoint1> <endpoint2> ...

set -e
RUN_ID="$1" && shift
BASE_DIR="claude-orchestrator/temp/$RUN_ID"

for endpoint in "$@"; do
    # Clean endpoint name for filename (remove /api/ prefix, replace / with _)
    clean_name=$(echo "$endpoint" | sed 's|^/api/||' | tr '/' '_')

    cat > "$BASE_DIR/prompts/test_${clean_name}.md" << EOF
# Task: Create tests for $endpoint API endpoint

Create comprehensive tests for the \`$endpoint\` API endpoint.

## Requirements:
- Test all HTTP methods (GET, POST, PUT, DELETE as applicable)
- Test success cases with valid data
- Test error cases (400, 401, 403, 404, 500)
- Test edge cases and boundary conditions
- Include authentication tests if applicable
- Use appropriate test framework

The test suite should provide confidence in the endpoint's reliability.
EOF

    echo "Generated: test_${clean_name}.md"
done
```

## Best Practices

### 1. Always Use Error Handling

```bash
set -e  # Exit on any error
if [[ -z "$RUN_ID" ]]; then
    echo "Usage: $0 <run_id> ..."
    exit 1
fi
```

### 2. Validate Run Directory

```bash
BASE_DIR="claude-orchestrator/temp/$RUN_ID"
if [[ ! -d "$BASE_DIR" ]]; then
    echo "Error: Run directory $BASE_DIR does not exist"
    exit 1
fi
```

### 3. Use Descriptive Task Names

```bash
# Good: Clear and unique
task_name="cleanup_${COUNTER}_$(basename "$file")"

# Bad: Generic and potentially conflicting
task_name="task_$COUNTER"
```

### 4. Avoid Complex String Parsing

```bash
# Avoid this (fragile with special characters):
IFS=':' read -ra PARTS <<< "$complex_string"

# Better: Use arrays or separate variables
declare -a files=("file1.js" "file2.ts" "file3.py")
declare -a descriptions=("Auth logic" "API handlers" "Utils")
```

### 5. Include Usage Examples

```bash
if [[ -z "$RUN_ID" ]]; then
    echo "Usage: $0 <run_id> <file1> <file2> ..."
    echo "Example: $0 run-123 src/auth.js src/api.ts"
    exit 1
fi
```

## Debugging Tips

### Check Generated Prompts

```bash
# After running your generator, check a few prompts:
cat claude-orchestrator/temp/run-123/prompts/task_1.md
```

### Test with Simple Cases First

```bash
# Start with 1-2 simple cases before running many
./your_generator.sh run-123 simple_file.js
```

### Common Issues to Avoid

1. **File naming conflicts** - Use counters or unique identifiers
2. **Special characters in filenames** - Clean/sanitize input
3. **Missing validation** - Check inputs and directories exist
4. **Heredoc issues** - Use `<< 'EOF'` to avoid variable expansion
5. **UTF-8 characters** - Be careful with string splitting

## Complete Workflow Example

```bash
# 1. Create run
RUN_ID=$(claude-orchestrator/setup_run.sh | grep "Run ID:" | cut -d' ' -f3)

# 2. Generate prompts
claude-orchestrator/cleanup_generator.sh $RUN_ID src/auth.js src/api.ts utils/helpers.py

# 3. Launch managers
claude-orchestrator/launch_managers.sh $RUN_ID

# 4. Monitor
claude-orchestrator/monitor.sh $RUN_ID 30
```
