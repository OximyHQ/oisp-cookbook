#!/bin/bash
#
# Auto-detect cookbook programming language
#
# Detection rules:
#   - requirements.txt → python
#   - package.json → node
#   - otherwise → unknown
#
# Usage:
#   ./detect-language.sh <cookbook-dir>
#
# Output:
#   Single word: python | node | unknown
#
# This script enables automatic language detection for the shared test harness,
# eliminating the need for explicit language configuration in each cookbook.

set -e

COOKBOOK_DIR="${1:?Cookbook directory required}"

if [ ! -d "$COOKBOOK_DIR" ]; then
    echo "ERROR: Directory not found: $COOKBOOK_DIR" >&2
    exit 1
fi

# Check for language markers
if [ -f "$COOKBOOK_DIR/requirements.txt" ]; then
    echo "python"
elif [ -f "$COOKBOOK_DIR/package.json" ]; then
    echo "node"
else
    echo "unknown"
fi
