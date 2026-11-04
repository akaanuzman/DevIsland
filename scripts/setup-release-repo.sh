#!/bin/bash
# Run once with a GitHub CLI login authorized to create this public repository and configure Pages.
set -euo pipefail
command -v gh >/dev/null || { echo "Install GitHub CLI (brew install gh), then run gh auth login." >&2; exit 1; }
gh auth status
repo=akaanuzman/DevIsland-releases
if ! gh api "repos/$repo" >/dev/null 2>&1; then
    gh repo create "$repo" --public --add-readme --description 'Official signed Dev Island macOS releases and update feed'
fi
test "$(gh api "repos/$repo" --jq .private)" = false
# A real branch must exist before Pages can be configured. No fake update is published here.
if ! gh api "repos/$repo/git/ref/heads/gh-pages" >/dev/null 2>&1; then
    sha="$(gh api "repos/$repo/git/ref/heads/main" --jq .object.sha)"
    gh api "repos/$repo/git/refs" --method POST -f ref=refs/heads/gh-pages -f sha="$sha" >/dev/null
fi
if gh api "repos/$repo/pages" >/dev/null 2>&1; then
    gh api "repos/$repo/pages" --method PUT -f 'source[branch]=gh-pages' -f 'source[path]=/' >/dev/null
else
    gh api "repos/$repo/pages" --method POST -f 'source[branch]=gh-pages' -f 'source[path]=/' >/dev/null
fi
echo 'Public releases repository and Pages configured. Add the release environment secrets before tagging a release.'
