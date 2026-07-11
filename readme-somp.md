# SOMP Notes

SOMP is Samson's fork/workspace for OMP.

Local repo:

```sh
~/sandbox/somp
```

Remotes:

```sh
origin   git@github.com:stupidanon/oh-my-pi.git
upstream https://github.com/can1357/oh-my-pi.git
```

## Goal

Keep the official OMP install untouched while editing and running a local fork.

`omp` stays the normal installed version.

`somp` runs the local built binary from:

```sh
~/sandbox/somp/packages/coding-agent/dist/omp
```

`~/.zshrc` has a `somp` helper for this. It is implemented as a zsh function:

```sh
somp() {
  local somp_root="$HOME/sandbox/somp"
  local somp_bin="$somp_root/packages/coding-agent/dist/omp"
  if [[ "$1" == "update" ]]; then
    shift
    if (( $# != 0 )); then
      echo "somp update does not accept options" >&2
      return 2
    fi
    (cd "$somp_root" && bun run somp:update)
    return
  fi
  if [[ ! -x "$somp_bin" ]]; then
    echo "somp build missing. Run: cd ~/sandbox/somp && bun install && bun run build:native && bun --cwd=packages/coding-agent run build" >&2
    return 127
  fi
  "$somp_bin" "$@"
}
```

## Branch Model

Use two branches:

```text
main  = clean upstream mirror
somp  = Samson's custom edits
```

Do day-to-day custom work on `somp`.

Avoid putting custom edits directly on `main`; keeping `main` clean makes upstream updates easier to reason about.

## Normal Edit Loop

```sh
cd ~/sandbox/somp
git switch somp
# edit code
bun --cwd=packages/coding-agent run build
somp
```

If TypeScript/package dependencies changed, run:

```sh
bun install
bun --cwd=packages/coding-agent run build
```

If Rust/native code changed, or the build complains about native addons, run:

```sh
bun run build:native
bun --cwd=packages/coding-agent run build
```

## One-Command SOMP Update

From a clean `somp` branch, run:

```sh
somp update
```

The shell wrapper maps this to `bun run somp:update` in the SOMP repository;
it does not invoke OMP's official binary self-updater.

The updater:

1. Verifies that the current branch is `somp` and the worktree is clean.
2. Fetches `upstream`, fast-forwards `main`, and pushes `origin/main`.
3. Creates a timestamped `somp-before-main-rebase-*` backup branch.
4. Rebases `somp` onto `main`.
5. Installs dependencies, rebuilds native components and the SOMP binary, and
   runs the dedicated smoke test.
6. Pushes the rebased `somp` branch with `--force-with-lease` only after every
   preceding step succeeds.

If the rebase has conflicts, the updater stops with the rebase still active.
Ask an AI coding agent:

```text
Resolve the current git rebase conflicts, preserve the SOMP customizations, then continue the rebase.
```

To cancel the interrupted update instead:

```sh
git rebase --abort
```

## Updating Clean Main

Only do this when `main` has no custom work:

```sh
cd ~/sandbox/somp
git switch main
git fetch upstream
git merge --ff-only upstream/main
git push origin main
git switch somp
```

The important part: keep `main` boring and keep experiments on `somp`.

## Updating SOMP From Main

Do this after `main` has been updated.

This keeps `somp` as Samson's custom branch, but moves its base forward:

```text
before: old main -> SOMP commits
after:  new main -> SOMP commits
```

Use rebase rather than squash. Squashing upstream into `somp` loses Git ancestry
and makes the next update harder. Rebase keeps the mental model simple:

```text
SOMP = latest upstream OMP + Samson's patch stack
```

Before rebasing, make a local backup pointer:

```sh
cd ~/sandbox/somp
git switch somp
git branch somp-before-main-rebase-$(date +%Y-%m-%d) somp
git rebase main
```

If rebase reports conflicts, resolve the files, then:

```sh
git add <resolved-files>
git rebase --continue
```

If the update is not worth dealing with yet:

```sh
git rebase --abort
```

After a successful rebase:

```sh
bun install
bun --cwd=packages/coding-agent run build
```

If Rust/native code changed during the upstream update, or if this was a large
upstream bump, do the full SOMP build:

```sh
bun install
bun run build:native
bun --cwd=packages/coding-agent run build
packages/coding-agent/dist/omp --version
```

## Keeping The Fork Backed Up

Push custom work to the fork branch:

```sh
git push origin somp
```

If the first push says the branch has no upstream:

```sh
git push -u origin somp
```

After a rebase, `somp` has new commit IDs. If the branch already exists on
GitHub, push it with:

```sh
git push --force-with-lease origin somp
```
