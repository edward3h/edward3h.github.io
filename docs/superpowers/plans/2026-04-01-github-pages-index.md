# GitHub Pages Index Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a dark-mode GitHub Pages index at `edward3h.github.io` with a `generate.sh` script that auto-discovers Pages-enabled repos via the GitHub API and writes `index.html`.

**Architecture:** `generate.sh` fetches repos via `gh api`, checks each for Pages status, and writes a complete standalone `index.html`. HTML generation is implemented as a bash function so it can be tested with fixture data independently of live API calls.

**Tech Stack:** bash 4+, `gh` CLI (authenticated), `jq` 1.6+

> **Note on branching:** For a GitHub Pages user site, `main` is the publication branch — commits go directly to `main` rather than a feature branch.

---

## Chunk 1: Setup, script, and output

### Task 1: Create `.gitignore`

**Files:**
- Create: `.gitignore`

- [ ] **Step 1: Write `.gitignore`**

```
.superpowers/
```

- [ ] **Step 2: Commit**

```bash
git add .gitignore
git commit -m "chore: add .gitignore"
```

---

### Task 2: Write the HTML generation function and test it with fixture data

This task writes the part of `generate.sh` that turns a list of repos into HTML. It is structured so it can be called with fixture data, making it testable without live API calls.

**Files:**
- Create: `generate.sh`
- Create: `test/fixture-repos.json` — fixture API data for testing
- Create: `test/test-generate.sh` — test runner

- [ ] **Step 1: Create fixture data**

Create `test/fixture-repos.json`:

```json
[
  {"name": "my-site", "description": "A demo site", "pages_url": "https://edward3h.github.io/my-site"},
  {"name": "another-project", "description": null, "pages_url": "https://edward3h.github.io/another-project"}
]
```

- [ ] **Step 2: Write the failing test**

Create `test/test-generate.sh`:

```bash
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
assert_contains "viewport"           "viewport"
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
```

- [ ] **Step 3: Run the test to confirm it fails (generate.sh doesn't exist yet)**

```bash
chmod +x test/test-generate.sh
bash test/test-generate.sh 2>&1 || true
```

Expected: error — `generate.sh` not found.

- [ ] **Step 4: Write `generate.sh` with the `render_html` function**

Create `generate.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# When sourced for testing, skip the main execution
if [[ "${1:-}" == "--source-only" ]]; then
  # Only define functions, do not run
  :
fi

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
```

- [ ] **Step 5: Make scripts executable**

```bash
chmod +x generate.sh test/test-generate.sh
```

- [ ] **Step 6: Run the test — verify it passes**

```bash
bash test/test-generate.sh
```

Expected output: all lines print `PASS:` and exit code 0.

- [ ] **Step 7: Commit**

```bash
git add generate.sh test/fixture-repos.json test/test-generate.sh
git commit -m "feat: add generate.sh with HTML generation and tests"
```

---

### Task 3: Run the script for real and commit `index.html`

- [ ] **Step 1: Verify `gh` is authenticated**

```bash
gh auth status
```

Expected: shows your authenticated account (`edward3h`). If not, run `gh auth login` first.

- [ ] **Step 2: Run the generation script**

```bash
./generate.sh
```

Expected: prints `Generated index.html (N lines)` with no errors.

- [ ] **Step 3: Inspect the output**

```bash
# Check the file was created and has content
wc -l index.html

# Check it contains the expected structure
grep -c 'class="card"' index.html
```

Expected: `index.html` exists with 60+ lines; grep reports the number of your Pages-enabled repos (may be 0 if none exist yet, in which case confirm "No projects yet." is present).

- [ ] **Step 4: Open `index.html` in a browser to verify the visual output**

```bash
xdg-open index.html 2>/dev/null || open index.html 2>/dev/null || echo "Open index.html manually in your browser"
```

Confirm: dark background, cards with repo names/descriptions/URLs, GitHub Profile button in header.

- [ ] **Step 5: Commit `index.html`**

```bash
git add index.html
git commit -m "feat: add generated index.html"
```

---

### Task 4: Commit spec and plan docs

- [ ] **Step 1: Add and commit documentation**

```bash
git add docs/
git commit -m "docs: add design spec and implementation plan"
```

---

### Task 5: Push and verify on GitHub Pages

- [ ] **Step 1: Push to remote**

```bash
git push -u origin main
```

- [ ] **Step 2: Wait for GitHub Pages to deploy (usually 1–2 minutes), then verify**

Open `https://edward3h.github.io` in a browser.

Expected: the dark-mode index page loads with the GitHub Profile button and any Pages-enabled repo cards.
