# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), dated rather than numbered, and with no `Unreleased` section — a skill is read at whatever revision you have checked out, so whatever is on the default branch is what every reader already has, and a section for work that has landed but not shipped would never close. The rule lives in the [ci](https://github.com/rokokol/ci-skill) skill, which owns what has no version.

## 2026-09-10

### Fixed

- **the completion drift check could not catch a missing short flag.** It matched flags as substrings, and `-f` is a substring of `--force` as `-h` is of `--help`, so whenever a long flag was offered its short twin always passed. It matches whole tokens now, counting the hyphen as part of one, since `grep -w` would accept `--help` inside `--help-all`. `check-templates.sh` had only ever run it on templates that agree; a fixture that offers `--force` and never `-f` now has to fail, naming `-f`
- **the env-baking wrapper recipe could make a tool loop forever.** When an earlier install without the flag had left the relative symlink in `bin/`, `cat >` wrote through it into the real script in `share/`, and the wrapper then `exec`ed itself. Reproduced: the symlink survives, the script is overwritten, and the tool runs until a timeout kills it. `references/install-sh.md` removes the entry before writing the wrapper

## 2026-09-07

### Added

- `check-skill.sh`, the gate every skill repository shares, copied verbatim from the [ci](https://github.com/rokokol/ci-skill) skill and run by `check-templates.sh`: `SKILL.md` loads (frontmatter closed, name valid and agreeing with the symlink, description within what an agent reads), every reference is reached from `SKILL.md` by a chain of real links, every link and anchor resolves — and each of those is proven able to fail on a planted defect every time the gate runs. This repository had no `SKILL.md` check at all before
- `check-templates.sh` now runs `templates/tests/check-completions.sh` on the template installer and completions, the way a target repository runs it on its own — the one template that is executed here rather than only linted; actionlints this repository's own `ci.yml` beside the template workflows; and requires `templates/VERSION` to be an `x.y.z`, its shape being all it can be checked against
- `check-pins.sh`, the pin guard for the workflows, copied verbatim from the [ci](https://github.com/rokokol/ci-skill) skill: it covers every unpinned shape the ci skill names rather than the one `nix run` grep this repository knew, proves on every run that it catches each one and stays quiet on the pinned spellings, and scans the template workflows beside this repository's own — the templates are workflows too

### Changed

- the unpinned-registry guard moved from an inline step in `ci.yml` into `check-templates.sh`, so it runs locally too and the workflow has one step to keep — and then from an inline grep into `check-pins.sh`, so the pattern has one source that travels by copying
- build.yml template: the guard step runs `check-pins.sh` instead of its own inline grep, so a target repository copies the file from the ci skill beside the workflow and widens the pattern by re-copying rather than by editing

## 2026-09-05

### Removed

- the generic half of `references/versioning.md`, to the [versioning](https://github.com/rokokol/versioning-skill) skill: where a version lives, which repositories have one at all, what a changelog looks like either way, and how a release is cut. What stays here is what is genuinely this family's — `package.nix` reading `VERSION` with `lib.fileContents`, `install.sh` printing it and installing a copy, and the red-run-first rule for adopting the check on a repo whose versions already disagree

## 2026-09-02

### Removed

- the skill's own `VERSION` file and the self-applied VERSION↔CHANGELOG step: a skill is read at whatever revision is checked out, so it has no version to be wrong about — versioning.md now says what has no version, and this changelog is dated rather than numbered. `templates/VERSION` stays: the repos this skill standardizes do ship a version

### Changed

- the CI doctrine left this skill entirely: `references/ci.md` is gone and SKILL.md links to the [ci](https://github.com/rokokol/ci-skill) skill, keeping only the nix-family concretes — `build.yml`'s job composition, `scripts-lint` as the one lint file list, and the family's cron wave

## 2026-09-01

### Added

- install-sh reference: the component-installer adaptation (from ddlc-themes, at the owner's call) — components are additive with a per-component sweep, manifest lines carry their owning component, and `--uninstall --component C` removes one selectively; plus the config-tree variant: no `--prefix`, the manifest under `<config-home>/<name>/`, version in the manifest header, pruning that stops at the owning home
- SKILL.md: the partial shape for repos with no install.sh (ddlc-palette, ddlc.nvim) — VERSION with the CI check, lint dedup and the registry guard in full, nothing installer-shaped
- the update-lock-race canon — a push rejected because the weekly bot bump landed mid-work is rebased onto, re-verified on the fresh lock (fmt, flake check, the fast suite), and pushed; never force-pushed over — recorded in the [ci](https://github.com/rokokol/ci-skill) skill, which this family follows
- distro-tests reference: the suite also tests the observer's network — a container-only download failure that the host answers 200 to (curl -sI probe) is Docker's bridge bypassing host VPN routing, met live as Cisco's CloudFront geo-403 on Fedora's openh264; verify locally with --network host, CI runners stay the source of truth
- build.yml template: when the preflight demands runtime tools beyond coreutils, the `install.sh works` step runs under `nix develop` — the runner is not a target distribution and a preflight refusing it is working as designed (virtual-media-devices' first push went red exactly this way)
- distro.sh template: the guidance answer stream is per-package-manager — pacman gets bare newlines (`yes ''`), because its provider-selection menus reject `y` as "invalid number" and re-prompt forever (caught live: virtual-media-devices' ffmpeg pulling jack hung Arch and grew a 9 GB log), while dnf keeps `y` (empty is No there); and every guidance command runs under `timeout`, so the next unpredicted prompt style is a red failure, not an unbounded hang
- install-sh reference, preflight (from virtual-media-devices): a third dependency class — platform deps (kernel modules), warn-only like session deps, and the distro smoke must skip the half that needs them; runtime tools an installed command shells out to are install deps; `need()` goes idempotent when components share one; a `pkg_for DISTRO BINARY` mapping prints one deduplicated per-distro `$ ` line when binaries and package names diverge
- install-sh reference, component installers (from ddlc-sddm-theme): shared bookkeeping (the installed VERSION copy) belongs to a `meta` pseudo-component — every install rewrites it, selective uninstalls keep it, and it leaves with the last real component; and the per-component sweep is what makes conditional files declarative — `--no-configure` needs no removal code, the unwritten config is swept
- distro-tests reference: no empty alternation in ERE assertions — `(a|b|)$` is rejected by some grep implementations; spell the empty case explicitly
- install-sh reference: the bin entry is a copy, not the relative symlink, when the tool derives its data directory from its own location in a non-`share/<name>` shape (ddlc-rofi-theme's switch) — matching what its Nix package installs
- install-sh reference, self-checks: the stub-PATH recipe for testing the refusal path (symlink `bash` too — `PATH="$stub" bash` resolves with the new PATH; point `OS_RELEASE` at a fixture, the sandbox has no `/etc/os-release`), and `patchShebangs` before running the suite inside a flake check — the sandbox has no `/usr/bin/env`

- the skill repo carries its own flake now: the lint toolbox is pinned by a lock and reached with `nix develop`, the same doctrine the [ci](https://github.com/rokokol/ci-skill) skill prescribes
- build.yml template: a guard step that fails on any `nix run|shell nixpkgs#` in the workflows — unpinned registry lookups broke family CI quietly more than once
- install-sh reference: when a formatter's opinion changes between versions (shfmt 3.14's `((! x))`), the lock bump and the reformat land as one commit — the old and new spellings reject each other

### Changed

- build.yml template: the relative-PREFIX negative assert is an if-form now — `set -e` ignores negated pipelines, so a `! cmd` line only bites while it happens to be last, and anyone appending a line disarms it silently
- lessons from skvpn's routed DinD suite: keep Docker as a harness-only dependency, use `--privileged` plus the `vfs` storage driver for overlay-on-overlay, pull fixtures before activating a blocking TUN, feature-detect Docker 29's nftables backend for Fedora's unusable legacy iptables namespace, and test dynamic `br-*` bridges/address pools rather than only `docker0`
- every binary a CI test runs must come from the flake's lock (via `devShells`), not from unpinned `nix shell nixpkgs#…` — a version change in an unpinned registry lookup silently breaks nftables chain names or table semantics and the job goes red (or green against different behaviour) for no change in repo code; the general rule now lives in the [ci](https://github.com/rokokol/ci-skill) skill
- lessons from the first rollout (skvpn): guidance commands are fed `yes` via process substitution, not a pipe (pipefail read yes's SIGPIPE death as failure); the bootstrap doctrine names its three legitimate kinds — test infrastructure, the package manager's own prerequisite, and the platform baseline the images strip but every real host has
- distro-tests reference: a "what the first runs actually caught" section — the suite tests assumptions about what a distribution provides, not your logic; probe the mechanism you depend on, never a proxy (uutils wc vouching for a locale bash never got); un-mute `2>/dev/null` pipelines first when one distro fails (Debian's jq 1.7 silently rejecting newer syntax); and a build runner is not a target distribution — its deps come from nix, the distro suite is where guidance provides them for real
- lessons from the fourth wave (claude-account, rofi-wooordhunt): the sudo shim is `exec env "$@"`, because a printed line may carry VAR=value assignments after sudo (GOBIN=... go install); the AUR arm builds by hand for real now — depends read from the PKGBUILD, makepkg without -si (its own sudo calls would hit the shim), pacman -U as root — exercised by rofi-wooordhunt's pup
- lessons from the second and third rollouts (hyprland-screen-shader, ddlc-hyprlock): the template installer carries the declarative sweep — paths a previous manifest names that the current run did not write are removed, which is what makes re-running without a flag undo it; env-baking wrappers are written via escaped heredocs, and the install-sh reference now says out loud that a linter is satisfied by rewriting, not by disable comments

## 2026-08-31

### Added

- The standard itself: VERSION as the single version source, the canonical install.sh (declarative flags, dependency preflight that never installs anything, uninstall by manifest, `--no-systemd`), hand-written install.sh completions with a machine drift check, docker-based distro tests that execute the preflight's own printed guidance, per-distro CI badges via one reusable workflow and four thin wrappers, and the deduplicated build/lint CI shape
- Templates for every piece, lintable raw thanks to the tokens-in-strings-only rule, checked by `check-templates.sh` against known-bad fixtures so the checker itself is proven able to fail
- References explaining each decision: install-sh, versioning, completions, distro-tests, ci, readme
