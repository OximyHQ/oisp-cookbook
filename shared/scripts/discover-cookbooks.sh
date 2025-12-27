#!/bin/bash
#
# Auto-discover testable cookbooks
#
# Convention: Any directory containing expected-events.json is a testable cookbook
#
# Usage:
#   ./discover-cookbooks.sh [base-dir]
#
# Output:
#   Newline-separated list of cookbook paths relative to base-dir
#   Example:
#     python/01-openai-simple
#     python/02-litellm
#     node/01-openai-simple
#
# This script enables convention-based cookbook testing:
# - No hardcoded lists to maintain
# - Adding new cookbook = instant discovery
# - Used by test-all.sh, Makefile, and GitHub Actions

set -e

BASE_DIR="${1:-.}"
cd "$BASE_DIR"

# Find all directories containing expected-events.json
# Exclude:
#   - shared/ directory (infrastructure, not a cookbook)
#   - Hidden directories (.*/)
find . -type f -name "expected-events.json" \
  -not -path "*/shared/*" \
  -not -path "*/.*" \
  -exec dirname {} \; | \
  sed 's|^\./||' | \
  sort
