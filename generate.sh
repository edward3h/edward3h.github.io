#!/usr/bin/env bash
set -euo pipefail

# ── HTML generation ──────────────────────────────────────────────────────────

# render_html <repos-json-file>
# Reads a JSON array of {name, description, pages_url} objects and writes
# a complete index.html to stdout.
render_html() {
  local repos_file="$1"

  local cards
  cards=$(jq -r '
    .[] |
    "<a class=\"card\" href=\"" + .pages_url + "\">" +
    "<div class=\"card-name\">" + .name + "</div>" +
    "<div class=\"card-desc\">" + (if .description == null or .description == "" then "No description provided." else .description end) + "</div>" +
    "<div class=\"card-url\">" + (.pages_url | ltrimstr("https://")) + "</div>" +
    "</a>"
  ' "$repos_file")

  local empty_state=""
  if [[ -z "$cards" ]]; then
    empty_state='<p style="text-align:center;color:#8b949e;">No projects yet.</p>'
  fi

  cat <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>edward3h — GitHub Pages</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    background: #0d1117;
    color: #e6edf3;
    padding: 2rem 1rem;
  }
  .container { max-width: 760px; margin: 0 auto; }
  header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 2rem;
    padding-bottom: 1rem;
    border-bottom: 1px solid #30363d;
  }
  header h1 { font-size: 1.5rem; font-weight: 600; }
  .profile-link {
    display: inline-flex;
    align-items: center;
    gap: 0.4rem;
    padding: 0.4rem 0.9rem;
    background: #238636;
    color: #fff;
    border-radius: 6px;
    text-decoration: none;
    font-size: 0.875rem;
    font-weight: 500;
    border: 1px solid #2ea043;
  }
  .profile-link:hover { background: #2ea043; }
  .subtitle {
    color: #8b949e;
    font-size: 0.875rem;
    margin-bottom: 1.5rem;
  }
  .cards {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
    gap: 1rem;
  }
  .card {
    background: #161b22;
    border: 1px solid #30363d;
    border-radius: 8px;
    padding: 1rem 1.25rem;
    display: flex;
    flex-direction: column;
    gap: 0.35rem;
    text-decoration: none;
    color: inherit;
    transition: border-color 0.15s, box-shadow 0.15s;
  }
  .card:hover {
    border-color: #58a6ff;
    box-shadow: 0 0 0 3px rgba(88,166,255,0.1);
  }
  .card-name { font-weight: 600; font-size: 1rem; color: #58a6ff; }
  .card-desc { font-size: 0.875rem; color: #8b949e; flex: 1; }
  .card-url  { font-size: 0.75rem; color: #6e7681; margin-top: 0.25rem; }
</style>
</head>
<body>
<div class="container">
  <header>
    <h1>edward3h</h1>
    <a class="profile-link" href="https://github.com/edward3h">&#128100; GitHub Profile</a>
  </header>
  <p class="subtitle">GitHub Pages sites</p>
  <div class="cards">
${cards}${empty_state}
  </div>
</div>
</body>
</html>
HTML
}

# ── API fetching ─────────────────────────────────────────────────────────────

# check_rate_limit <stderr-output>
# Exits with error message if output contains a rate-limit message.
check_rate_limit() {
  local stderr_output="$1"
  if echo "$stderr_output" | grep -qi "API rate limit exceeded"; then
    echo "Error: GitHub API rate limit reached. Try again later." >&2
    exit 1
  fi
}

# fetch_pages_repos <owner> <tmp-file>
# Writes a JSON array of {name, description, pages_url} to <tmp-file>.
fetch_pages_repos() {
  local owner="$1"
  local out_file="$2"

  local repos_json stderr_out
  stderr_out=$(mktemp)

  # Fetch all public repos
  if ! repos_json=$(gh api --paginate --jq '.[]' "/users/${owner}/repos" 2>"$stderr_out"); then
    check_rate_limit "$(cat "$stderr_out")"
    echo "Error: failed to list repositories." >&2
    rm -f "$stderr_out"
    exit 1
  fi
  check_rate_limit "$(cat "$stderr_out")"
  rm -f "$stderr_out"

  # Filter out the user site repo and check Pages for each remaining repo
  local result="[]"
  while IFS= read -r repo_json; do
    local name description
    name=$(echo "$repo_json" | jq -r '.name')
    description=$(echo "$repo_json" | jq -r '.description // empty')

    # Skip the user site repo itself
    if [[ "$name" == "${owner}.github.io" ]]; then
      continue
    fi

    # Check if Pages is enabled
    local pages_stderr pages_out
    pages_stderr=$(mktemp)
    if pages_out=$(gh api "/repos/${owner}/${name}/pages" 2>"$pages_stderr"); then
      check_rate_limit "$(cat "$pages_stderr")"
      rm -f "$pages_stderr"

      # Use html_url from Pages API, fall back to constructed URL
      local pages_url
      pages_url=$(echo "$pages_out" | jq -r '.html_url // empty')
      if [[ -z "$pages_url" ]]; then
        pages_url="https://${owner}.github.io/${name}"
      fi

      result=$(echo "$result" | jq \
        --arg name "$name" \
        --arg desc "$description" \
        --arg url "$pages_url" \
        '. + [{"name": $name, "description": (if $desc == "" then null else $desc end), "pages_url": $url}]')
    else
      local pages_err
      pages_err=$(cat "$pages_stderr")
      check_rate_limit "$pages_err"
      rm -f "$pages_stderr"

      # 404 = no Pages, any other error = warn and skip
      if ! echo "$pages_err" | grep -q "HTTP 404"; then
        echo "Warning: unexpected error checking Pages for ${name}, skipping." >&2
      fi
    fi
  done < <(echo "$repos_json" | jq -c '.')

  echo "$result" > "$out_file"
}

# ── Main ─────────────────────────────────────────────────────────────────────

if [[ "${1:-}" != "--source-only" ]]; then
  OWNER="edward3h"
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  TMP_REPOS=$(mktemp)

  fetch_pages_repos "$OWNER" "$TMP_REPOS"
  render_html "$TMP_REPOS" > "$SCRIPT_DIR/index.html"
  rm -f "$TMP_REPOS"

  echo "Generated index.html ($(wc -l < "$SCRIPT_DIR/index.html") lines)"
fi
