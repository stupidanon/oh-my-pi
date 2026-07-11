#!/bin/sh
set -eu

fail() {
  printf 'somp update: %s\n' "$1" >&2
  exit 1
}

repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || fail "run this command inside the SOMP repository"
cd "$repo_root"

current_branch=$(git branch --show-current)
[ "$current_branch" = "somp" ] || fail "start on the somp branch (currently on ${current_branch:-detached HEAD})"
[ -z "$(git status --porcelain)" ] || fail "working tree is not clean; commit or stash your changes first"
git remote get-url upstream >/dev/null 2>&1 || fail "missing upstream remote"
git remote get-url origin >/dev/null 2>&1 || fail "missing origin remote"
git show-ref --verify --quiet refs/heads/main || fail "missing local main branch"

backup="somp-before-main-rebase-$(date +%Y-%m-%d-%H%M%S)"

printf '%s\n' "==> Fetching upstream"
git fetch upstream

printf '%s\n' "==> Fast-forwarding main"
git switch main
git merge --ff-only upstream/main
git push origin main

printf '%s\n' "==> Rebasing somp (backup: $backup)"
git switch somp
git branch "$backup" somp
if ! git rebase main; then
  cat >&2 <<EOF

SOMP rebase stopped because conflicts need resolution.
The repository is still in the rebase so an AI coding agent can inspect and fix it.

Ask the AI:
  Resolve the current git rebase conflicts, preserve the SOMP customizations, then continue the rebase.

Manual recovery:
  git status
  # resolve each conflicted file
  git add <resolved-files>
  git rebase --continue

To cancel instead:
  git rebase --abort

Backup branch: $backup
EOF
  exit 1
fi

printf '%s\n' "==> Installing dependencies"
bun install

printf '%s\n' "==> Building native components"
bun run build:native

printf '%s\n' "==> Building SOMP"
bun --cwd=packages/coding-agent run build

# The binary build refreshes these registries as an intermediate step. They are
# not part of an upstream update and the command started from a clean tree.
git restore -- \
  packages/coding-agent/src/extensibility/plugins/legacy-pi-bundled-keys.ts \
  packages/coding-agent/src/extensibility/plugins/legacy-pi-bundled-registry.ts

[ -z "$(git status --porcelain)" ] || fail "build left unexpected tracked or untracked changes; inspect git status before pushing"

printf '%s\n' "==> Verifying SOMP"
packages/coding-agent/dist/omp --version
packages/coding-agent/dist/omp --smoke-test

printf '%s\n' "==> Updating origin/somp"
git push --force-with-lease origin somp

printf '\nSOMP update complete. Backup branch: %s\n' "$backup"
