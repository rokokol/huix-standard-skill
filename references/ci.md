# CI — one build.yml, one lint list, badges that mean something

The provider-general doctrine — gate vs detector, pinning, the callable build workflow, the bump cascade, falsifiable checks — lives in the [ci-standard](https://github.com/rokokol/ci-standard) skill; this file keeps the nix-family concretes on top of it.

Templates: [`templates/github/workflows/`](../templates/github/workflows/). Action pins are `actions/checkout@v7` and `cachix/install-nix-action@v31`, watched by dependabot (`github-actions` ecosystem, weekly).

## build.yml

Triggers: push to master, pull_request, workflow_dispatch, **and `workflow_call` with a `ref` input** — the last one is not optional: `update-lock.yml`'s verify job calls build.yml against the bump branch, and without `workflow_call`+`ref` that verification silently checks out master instead. This drift already existed in the family; adopting the standard fixes it everywhere.

Job `nix`: the VERSION↔CHANGELOG step ([versioning.md](versioning.md)) → `nix build` → `nix flake check` → an `install.sh works` step (staging install, manifest exists, uninstall empties it, relative PREFIX refused, plus repo-specific asserts) → `nix fmt -- --ci`.

When the repo's preflight demands runtime tools (ffmpeg, sing-box — anything beyond coreutils), the `install.sh works` step runs under `nix develop`: the runner is not a target distribution, so those deps come pinned from the lock, and the dev shell carries them. The honest install-by-guidance path belongs to the distro suite alone — a preflight that refuses the runner is working as designed, not a bug to soften.

Job `shell`: exactly one command — `nix build .#checks.x86_64-linux.scripts-lint`. **The file list lives in the flake's `scripts-lint` check and nowhere else.** Before the standard, the same shellcheck/shfmt commands ran in two places with two hand-maintained file lists; now the CI job is a fast named status for the flake check. Consequence: `scripts-lint` must absorb everything only CI linted before — completion files, test stubs, `tests/distro.sh`, `tests/check-completions.sh` — and it also runs the completions drift check.

## update-lock.yml

Weekly bump→verify→land cascade, templated as-is: bump every input onto a temp `flake-lock/<date>` branch, verify by calling build.yml (the workflow itself, not a copy of its commands) against that ref, fast-forward master and delete the branch only on green. `concurrency: update-lock`. In the huix family the crons form a wave (palette 05:00 → consumers 06:00 → huix 07:00) so upstream data flows through in one morning — that choreography is a family fact, not part of the template.

## Distro workflows

`distro.yml` is reusable (`workflow_call`, input `distro`, `runs-on: ubuntu-latest` — docker is preinstalled, `timeout-minutes: 30`). Four wrappers `distro-{debian,ubuntu,arch,fedora}.yml` exist only because a GitHub status badge is per-workflow-file; each is ~15 lines and delegates everything. Triggers on the wrappers: push to master, weekly cron (05:00, before the update-lock wave), workflow_dispatch — **no pull_request**: a Debian mirror having an afternoon must not redden someone's change; the weekly `:latest` run is the upstream-drift detector that requirement exists for.

Repo-specific weekly bots (palette-drift, canonize, upstream re-fetch) follow the same shape — `git diff --quiet` early exit, `github-actions[bot]` identity, dated branch, `gh pr` create-or-edit — but stay per-repo; they are examples of the pattern, not templates.

## Pinning CI dependencies via the flake

Every binary a CI job runs must come from the flake's own lock, not from an unpinned registry lookup. `nix shell nixpkgs#pkg` or `nix run nixpkgs#pkg` in a workflow pulls whatever nixpkgs the runner's channel points at today — a different sing-box version can change nftables chain names, a different nftables can change table semantics, and the job goes red (or worse, green against different behaviour) for no change in the repo's own code.

The fix is mechanical: add the needed tools to the repo's `devShells` (or a dedicated CI shell) so the lock file pins them, and call `nix develop` instead. A pinned shell is a reproducible assertion; an unpinned `nix shell` is a mirror-fate test that does not belong in a release gate. This applies to runtime-adjacent test tools (sing-box, nftables, iptables) and to linters alike — if the tool's output matters, pin it.
