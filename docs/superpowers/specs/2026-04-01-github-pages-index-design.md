# GitHub Pages Index — Design Spec

**Date:** 2026-04-01

## Context

`edward3h.github.io` is a GitHub Pages user site (currently empty). The goal is an index page that acts as a landing page, linking to the owner's GitHub profile and to each repository that has GitHub Pages enabled. A local generation script keeps the page up to date when new repos gain a Pages site.

## What We're Building

Two files in the repository root:

| File | Purpose |
|------|---------|
| `index.html` | The generated page, committed and served by GitHub Pages |
| `generate.sh` | Executable shell script to regenerate `index.html` |

`generate.sh` must have a `#!/usr/bin/env bash` shebang and be executable (`chmod +x`). It writes `index.html` to the repository root (the same directory as `generate.sh`).

## Page Design

- **Dark mode** — GitHub dark palette:
  - Page background: `#0d1117`
  - Card background: `#161b22`
  - Borders: `#30363d`
  - Link colour: `#58a6ff`
  - Muted text: `#8b949e`
  - Very muted text (URL): `#6e7681`
- **HTML boilerplate** — `<meta charset="utf-8">`, `<meta name="viewport" content="width=device-width, initial-scale=1">`, `<title>edward3h — GitHub Pages</title>`
- **Header** — username (`edward3h`) on the left; a green "GitHub Profile" button on the right linking to `https://github.com/edward3h`
  - Button background: `#238636`, hover: `#2ea043`, border: `#2ea043`
- **Cards grid** — responsive `auto-fill` grid (min 300 px per card); each card links to the Pages URL and shows:
  - Repo name (blue `#58a6ff`, bold)
  - Repo description (muted grey; falls back to "No description provided." if absent)
  - Pages URL in small very-muted text
- **Empty state** — if no Pages-enabled repos are found, display a centred paragraph: "No projects yet."
- No external dependencies — plain HTML and inline CSS only

## Generation Script (`generate.sh`)

### Dependencies

- `gh` CLI (authenticated — `gh auth status` must pass)
- `bash` 4+
- `jq` 1.6+

### Logic

1. Fetch all public repos with `gh api --paginate --jq '.[]' /users/edward3h/repos`. Using `--jq '.[]'` streams individual objects rather than concatenating raw JSON arrays, which produces valid input for subsequent `jq` processing.

2. Exclude the user site repo by filtering on `.name == "edward3h.github.io"`.

3. For each remaining repo, call `gh api /repos/edward3h/{repo}/pages`. Before treating a non-200 response as "skip", check whether `gh`'s stderr contains `"API rate limit exceeded"` (case-insensitive match). If it does, abort immediately (see step 5). Otherwise:
   - **200** — Pages is enabled. Use the `html_url` field from the response as the Pages URL. Fall back to `https://edward3h.github.io/{repo}` only if `html_url` is null or empty.
   - **404** — Pages not enabled. Skip.
   - **Any other non-rate-limit failure** — log a warning to stderr (`echo "Warning: unexpected status for {repo}, skipping" >&2`) and skip. This covers 403 (private repo), 451, network errors, etc.

4. Collect for each accepted repo: name, description (from the repos listing), Pages URL.

5. **Rate-limit abort** — applies to both the initial repo listing (step 1) and each per-repo pages call (step 3). If `gh`'s stderr output contains the string `"API rate limit exceeded"` (case-insensitive), abort immediately with: `echo "Error: GitHub API rate limit reached. Try again later." >&2; exit 1`. This check takes precedence over the "skip" rule in step 3.

6. Write a complete `index.html` to the repository root using the dark-mode design above.

### Usage

```bash
./generate.sh
# Review index.html, then commit and push
git add index.html
git commit -m "Regenerate index"
git push
```

## Verification

1. Run `./generate.sh` — `index.html` should be created/updated in the repo root.
2. Open `index.html` in a browser locally — confirm dark-mode layout, cards with name/description/URL, and the GitHub Profile button.
3. Confirm the `edward3h.github.io` repo itself does not appear as a card.
4. Push to `main` on `edward3h.github.io` and visit `https://edward3h.github.io` to confirm GitHub Pages serves the page.
5. To verify the empty state, temporarily run the script with a GitHub user that has no Pages repos and confirm "No projects yet." is displayed.

## Future Considerations

- GitHub Actions workflow to run `generate.sh` on a schedule and auto-commit `index.html`
