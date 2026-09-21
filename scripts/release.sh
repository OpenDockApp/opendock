#!/usr/bin/env bash
# Bump the version, tag it and push the tag. The tag triggers the release workflow.
# Usage: scripts/release.sh [patch|minor|major]
#        With no argument it asks which bump to make.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

die() { echo "error: $*" >&2; exit 1; }

[[ "$(git rev-parse --abbrev-ref HEAD)" == "main" ]] || die "releases are cut from main only"
[[ -z "$(git status --porcelain)" ]] || die "working tree is not clean"

git fetch --quiet origin main --tags
[[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/main)" ]] || die "main is not in sync with origin/main"

LATEST="$(git tag --list 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname | grep -Ev -- '-' | head -1 || true)"
LATEST="${LATEST:-v0.0.0}"
IFS='.' read -r MAJOR MINOR PATCH <<< "${LATEST#v}"

BUMP="${1:-}"
if [[ -z "$BUMP" ]]; then
  echo "Latest release: $LATEST"
  echo "  1) patch  -> v${MAJOR}.${MINOR}.$((PATCH + 1))"
  echo "  2) minor  -> v${MAJOR}.$((MINOR + 1)).0"
  echo "  3) major  -> v$((MAJOR + 1)).0.0"
  read -r -p "Bump [1/2/3]: " CHOICE
  case "$CHOICE" in
    1|patch) BUMP=patch ;;
    2|minor) BUMP=minor ;;
    3|major) BUMP=major ;;
    *) die "invalid choice: $CHOICE" ;;
  esac
fi

case "$BUMP" in
  patch) NEXT="v${MAJOR}.${MINOR}.$((PATCH + 1))" ;;
  minor) NEXT="v${MAJOR}.$((MINOR + 1)).0" ;;
  major) NEXT="v$((MAJOR + 1)).0.0" ;;
  *) die "usage: release.sh [patch|minor|major]" ;;
esac

git rev-parse -q --verify "refs/tags/$NEXT" >/dev/null && die "tag $NEXT already exists"

echo
if [[ "$LATEST" != "v0.0.0" ]]; then
  echo "Changes since $LATEST:"
  git log --oneline "$LATEST..HEAD"
  echo
fi
read -r -p "Tag and push $NEXT? [y/N] " CONFIRM
[[ "$CONFIRM" =~ ^[Yy]$ ]] || die "aborted"

git tag -a "$NEXT" -m "$NEXT"
git push origin "$NEXT"

echo "Pushed $NEXT. The release workflow is running."
