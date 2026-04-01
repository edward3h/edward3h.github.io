#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

source "$REPO_ROOT/generate.sh" --source-only

# Run the HTML generation function with fixture data
FIXTURE="$SCRIPT_DIR/fixture-repos.json"
output=$(render_html "$FIXTURE")

# Assertions
fail=0

assert_contains() {
  local label="$1" expected="$2"
  if echo "$output" | grep -qF "$expected"; then
    echo "PASS: $label"
  else
    echo "FAIL: $label — expected to find: $expected"
    fail=1
  fi
}

assert_contains "doctype"            "<!DOCTYPE html>"
assert_contains "charset"            'charset="utf-8"'
assert_contains "viewport"           'content="width=device-width, initial-scale=1"'
assert_contains "title"              "edward3h"
assert_contains "dark background"    "#0d1117"
assert_contains "profile link"       "https://github.com/edward3h"
assert_contains "repo name"          "my-site"
assert_contains "repo description"   "A demo site"
assert_contains "repo url"           "edward3h.github.io/my-site"
assert_contains "another repo name"  "another-project"
assert_contains "null description fallback" "No description provided."
assert_contains "pages link"         "https://edward3h.github.io/another-project"

exit $fail
