#!/usr/bin/env bash
# publish.sh — publish this folder to GitHub Pages (https://goutham.motati.me/)
#
#   ./publish.sh "what changed"      commit everything + push to origin/main (= live)
#   ./publish.sh                     same, with an auto "Publish YYYY-MM-DD HH:MM" message
#   ./publish.sh --dry-run           show what would be committed/pushed, change nothing
#
# Pages serves the root of `main`, so a push IS the deploy (live in ~1 min).
# The script (1) refuses to publish private workspace paths, (2) pulls first so
# edits made on github.com (e.g. CNAME) don't reject the push, (3) commits, (4) pushes.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BRANCH="main"
LIVE_URL="https://goutham.motati.me/"
REPO_URL="https://github.com/goutham-hienra/gouthammotati"
cd "$REPO"

DRY=0
if [[ "${1:-}" == "--dry-run" || "${1:-}" == "-n" ]]; then DRY=1; shift; fi
MSG="${1:-Publish $(date '+%Y-%m-%d %H:%M')}"

# --- 0. Must be on the branch Pages serves --------------------------------
CUR="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$CUR" != "$BRANCH" ]]; then
  echo "✗ On branch '$CUR' — publish only from '$BRANCH'." >&2; exit 1
fi

# --- 1. Leak guard: private design-workspace material never goes public ----
PRIVATE='(^|/)(Knowledge Base|Sessions|Case Studies|Projects)(/|$)|_session-context\.md$|\.case-study\.md$|(^|/)\.env$'
LEAK="$(git status --porcelain --untracked-files=all | cut -c4- | sed 's/^"//; s/"$//' | grep -E "$PRIVATE" || true)"
if [[ -n "$LEAK" ]]; then
  echo "✗ Refusing to publish — private paths found in the working tree:" >&2
  echo "$LEAK" | sed 's/^/    /' >&2
  echo "  Move them out of the repo (they belong in ~/Documents/Portfolio)." >&2; exit 1
fi

# --- 2. Sync with the remote before committing ----------------------------
git fetch -q origin "$BRANCH"
if ! git merge-base --is-ancestor "origin/$BRANCH" HEAD; then
  echo "• Remote has new commits — integrating first"
  git pull -q --rebase --autostash origin "$BRANCH"
fi

# --- 3. Show / stage / commit ---------------------------------------------
if [[ -z "$(git status --porcelain --untracked-files=all)" ]]; then
  echo "• Working tree clean — nothing new to commit"
else
  echo "• Changes:"; git status --short --untracked-files=all | sed 's/^/    /'
  if (( DRY )); then
    echo "• dry-run: would commit \"$MSG\" and push to origin/$BRANCH"; exit 0
  fi
  git add -A
  git commit -q -m "$MSG"
  echo "✓ Committed $(git rev-parse --short HEAD): $MSG"
fi

# --- 4. Push (= deploy) ---------------------------------------------------
AHEAD="$(git rev-list --count "origin/$BRANCH..HEAD")"
if (( DRY )); then
  echo "• dry-run: $AHEAD commit(s) would be pushed to origin/$BRANCH"; exit 0
fi
if [[ "$AHEAD" == "0" ]]; then
  echo "• Already published — nothing to push"
else
  git push -q origin "$BRANCH"
  echo "✓ Pushed $AHEAD commit(s) → $REPO_URL"
fi
echo "→ Live in ~1 min at $LIVE_URL"
