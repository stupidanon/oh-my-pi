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
  local somp_bin="$HOME/sandbox/somp/packages/coding-agent/dist/omp"
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

## Pulling Upstream Updates

From the `somp` branch:

```sh
cd ~/sandbox/somp
git switch somp
git fetch upstream
git rebase upstream/main
bun install
bun --cwd=packages/coding-agent run build
```

Use rebase rather than merge for this fork. The mental model stays simple:

```text
SOMP = latest upstream OMP + Samson's patch stack
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

## Keeping The Fork Backed Up

Push custom work to the fork branch:

```sh
git push origin somp
```

If the first push says the branch has no upstream:

```sh
git push -u origin somp
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
