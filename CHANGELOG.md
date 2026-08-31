# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- lessons from the first rollout (skvpn): guidance commands are fed `yes` via process substitution, not a pipe (pipefail read yes's SIGPIPE death as failure); the bootstrap doctrine names its three legitimate kinds — test infrastructure, the package manager's own prerequisite, and the platform baseline the images strip but every real host has
- lessons from the fourth wave (claude-account, rofi-wooordhunt): the sudo shim is `exec env "$@"`, because a printed line may carry VAR=value assignments after sudo (GOBIN=... go install); the AUR arm builds by hand for real now — depends read from the PKGBUILD, makepkg without -si (its own sudo calls would hit the shim), pacman -U as root — exercised by rofi-wooordhunt's pup
- lessons from the second and third rollouts (hyprland-screen-shader, ddlc-hyprlock): the template installer carries the declarative sweep — paths a previous manifest names that the current run did not write are removed, which is what makes re-running without a flag undo it; env-baking wrappers are written via escaped heredocs, and the install-sh reference now says out loud that a linter is satisfied by rewriting, not by disable comments

## [1.0.0] - 2026-08-31

### Added

- The standard itself: VERSION as the single version source, the canonical install.sh (declarative flags, dependency preflight that never installs anything, uninstall by manifest, `--no-systemd`), hand-written install.sh completions with a machine drift check, docker-based distro tests that execute the preflight's own printed guidance, per-distro CI badges via one reusable workflow and four thin wrappers, and the deduplicated build/lint CI shape
- Templates for every piece, lintable raw thanks to the tokens-in-strings-only rule, checked by `check-templates.sh` against known-bad fixtures so the checker itself is proven able to fail
- References explaining each decision: install-sh, versioning, completions, distro-tests, ci, readme
