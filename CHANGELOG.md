# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- install-sh reference: the component-installer adaptation (from ddlc-themes, at the owner's call) — components are additive with a per-component sweep, manifest lines carry their owning component, and `--uninstall --component C` removes one selectively; plus the config-tree variant: no `--prefix`, the manifest under `<config-home>/<name>/`, version in the manifest header, pruning that stops at the owning home
- install-sh reference, self-checks: the stub-PATH recipe for testing the refusal path (symlink `bash` too — `PATH="$stub" bash` resolves with the new PATH; point `OS_RELEASE` at a fixture, the sandbox has no `/etc/os-release`), and `patchShebangs` before running the suite inside a flake check — the sandbox has no `/usr/bin/env`

- the skill repo carries its own flake now: the lint toolbox is pinned by a lock and reached with `nix develop`, the same doctrine references/ci.md prescribes
- build.yml template: a guard step that fails on any `nix run|shell nixpkgs#` in the workflows — unpinned registry lookups broke family CI quietly more than once
- install-sh reference: when a formatter's opinion changes between versions (shfmt 3.14's `((! x))`), the lock bump and the reformat land as one commit — the old and new spellings reject each other

### Changed

- build.yml template: the relative-PREFIX negative assert is an if-form now — `set -e` ignores negated pipelines, so a `! cmd` line only bites while it happens to be last, and anyone appending a line disarms it silently
- the provider-general CI doctrine moved out to the ci-standard skill; references/ci.md points there and keeps the nix-family concretes
- lessons from skvpn's routed DinD suite: keep Docker as a harness-only dependency, use `--privileged` plus the `vfs` storage driver for overlay-on-overlay, pull fixtures before activating a blocking TUN, feature-detect Docker 29's nftables backend for Fedora's unusable legacy iptables namespace, and test dynamic `br-*` bridges/address pools rather than only `docker0`
- CI reference: every binary a CI test runs must come from the flake's lock (via `devShells`), not from unpinned `nix shell nixpkgs#…` — a version change in an unpinned registry lookup silently breaks nftables chain names or table semantics and the job goes red (or green against different behaviour) for no change in repo code
- lessons from the first rollout (skvpn): guidance commands are fed `yes` via process substitution, not a pipe (pipefail read yes's SIGPIPE death as failure); the bootstrap doctrine names its three legitimate kinds — test infrastructure, the package manager's own prerequisite, and the platform baseline the images strip but every real host has
- distro-tests reference: a "what the first runs actually caught" section — the suite tests assumptions about what a distribution provides, not your logic; probe the mechanism you depend on, never a proxy (uutils wc vouching for a locale bash never got); un-mute `2>/dev/null` pipelines first when one distro fails (Debian's jq 1.7 silently rejecting newer syntax); and a build runner is not a target distribution — its deps come from nix, the distro suite is where guidance provides them for real
- lessons from the fourth wave (claude-account, rofi-wooordhunt): the sudo shim is `exec env "$@"`, because a printed line may carry VAR=value assignments after sudo (GOBIN=... go install); the AUR arm builds by hand for real now — depends read from the PKGBUILD, makepkg without -si (its own sudo calls would hit the shim), pacman -U as root — exercised by rofi-wooordhunt's pup
- lessons from the second and third rollouts (hyprland-screen-shader, ddlc-hyprlock): the template installer carries the declarative sweep — paths a previous manifest names that the current run did not write are removed, which is what makes re-running without a flag undo it; env-baking wrappers are written via escaped heredocs, and the install-sh reference now says out loud that a linter is satisfied by rewriting, not by disable comments

## [1.0.0] - 2026-08-31

### Added

- The standard itself: VERSION as the single version source, the canonical install.sh (declarative flags, dependency preflight that never installs anything, uninstall by manifest, `--no-systemd`), hand-written install.sh completions with a machine drift check, docker-based distro tests that execute the preflight's own printed guidance, per-distro CI badges via one reusable workflow and four thin wrappers, and the deduplicated build/lint CI shape
- Templates for every piece, lintable raw thanks to the tokens-in-strings-only rule, checked by `check-templates.sh` against known-bad fixtures so the checker itself is proven able to fail
- References explaining each decision: install-sh, versioning, completions, distro-tests, ci, readme
