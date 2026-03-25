#!/bin/bash
file=$(jq -r '.tool_input.file_path')
[[ "$file" == *.rb ]] && bundle exec rubocop --autocorrect --fail-level error "$file" 2>&1 || true
