---
name: huix-standard
description: "What it is — a standard for making Nix-flake-first Linux repos installable on any distribution: a canonical install.sh (version, uninstall by manifest, dependency preflight that never installs anything), tab completion for the installer, docker-based distro tests with per-distro CI badges, and shared lint/CI conventions. Use when adding non-Nix install support to a repo, writing or extending an install.sh, adding VERSION handling, distro tests, CI badges, or when starting a new repo that should follow the family standard. Triggers: install.sh, uninstall, VERSION, distro tests, дистрибутивы, установка без nix, бейджи CI."
license: MIT
---

# huix-standard

A repo in this family is Nix-first: the flake is the source of truth for what the tool needs and how it is configured. `install.sh` is the same mechanism for everyone else — not a second product, but a faithful projection of the flake onto `/usr/local`. This skill is the checklist and the parts box for building that projection the same way every time.

Read the reference for the piece you are working on before writing code; copy templates from `templates/` (they mirror the target repo's paths) and replace `@NAME@` / `@OWNER@` / `@REPO@` tokens. When applying the standard to a repo teaches you something the templates got wrong, fix the template in the same sitting and add a CHANGELOG bullet here — the standard is only real while the repos and the skill agree.

## Non-negotiable decisions

These were argued once; do not re-litigate them per repo:

- **One source of version.** A `VERSION` file at the repo root. `nix/package.nix` reads it with `lib.fileContents ../VERSION`; `install.sh -v|--version` prints it; CI asserts `CHANGELOG.md` has a `## [$(cat VERSION)]` heading. See [references/versioning.md](references/versioning.md).
- **Short flags.** Wherever a tool or installer accepts `--help`, `--version`, `--force`, it also accepts `-h`, `-v`, `-f`. Completions update in the same commit — the drift check enforces it.
- **One flag per boolean.** Named so its presence flips the default (`--tailscale`, `--no-restore`); never a `--x`/`--no-x` pair. Consequence: install.sh is declarative — each run converges the system to exactly the flags given, and re-running without a flag undoes what the flag did.
- **Installer flags mirror only install-affecting options.** Nix module options that change installed artifacts get flags; runtime tunables stay environment variables, documented in a dedicated `--help` section and in the README.
- **Dependencies are never installed silently.** The preflight collects everything missing and prints exact per-distro remediation; runnable commands are printed as `  $ command` lines (two spaces, dollar, space) — the distro tests execute exactly those lines, so a typo in the guidance is a red CI run, not an undiscovered lie. AUR counts as official on Arch (`$ paru -S pkg`). Where no official package exists, print the ONE recommended method. See [references/install-sh.md](references/install-sh.md).
- **Uninstall by manifest.** The install writes every path it created (final runtime paths, no DESTDIR) to `share/<name>/install-manifest`; `--uninstall` consumes it. See [references/install-sh.md](references/install-sh.md).
- **bin/ holds a relative symlink** into `share/<name>/` where the script and its data live; the script resolves itself with `readlink -f` and finds data in its own directory. A generated two-line exec wrapper replaces the symlink only when install flags bake environment defaults (the non-Nix analog of `wrapProgram --set-default`).
- **Distro tests run on push to master, weekly cron, and dispatch — never on pull requests.** A flaky mirror must not redden someone's PR; the weekly run on `:latest` images is the upstream-drift detector. Per-distro badges require per-workflow files: one reusable `distro.yml` plus four thin wrappers. See [references/distro-tests.md](references/distro-tests.md) and [references/ci.md](references/ci.md).
- **Every check must be able to fail, and that is demonstrated, not assumed.** A new test runs red against the pre-fix state (or a deliberately broken fixture) before the code that turns it green exists. Checkers ship self-tests against known-bad fixtures. Assertions on printed guidance match whole lines (`grep -qxF`), never substrings.

## Adoption checklist

Work through this in order when bringing a repo up to standard:

1. `VERSION` file; `nix/package.nix` reads it; `install.sh` gains `-v|--version`; CI gains the VERSION↔CHANGELOG step — run it red first if the repo's versions already disagree ([references/versioning.md](references/versioning.md)).
2. `install.sh` reworked onto the canonical skeleton: flag grammar, preflight with `$ `-prefixed guidance, manifest, `--uninstall`, declarative booleans, `--no-systemd` where the repo touches systemd ([references/install-sh.md](references/install-sh.md), template `templates/install.sh`).
3. `completions/install.sh.bash` + `completions/install.sh.zsh` from templates; drift check wired into `scripts-lint` ([references/completions.md](references/completions.md)).
4. `tests/distro.sh` from template, adapted; run each distro locally in docker before pushing ([references/distro-tests.md](references/distro-tests.md)).
5. Workflows: `distro.yml` + four wrappers; `build.yml` brought to canon (workflow_call+ref, version step, lint deduped into the flake's `scripts-lint`) ([references/ci.md](references/ci.md)).
6. README: four distro badges after the build badge; document `--uninstall`, completions sourcing, runtime env vars ([references/readme.md](references/readme.md)).
7. CHANGELOG bullets for every user-visible change; CLAUDE.md layout/build sections updated.
8. Backport: diff what this repo needed against the templates; generalize the difference into this skill.

A repo with no `install.sh` — pure data (ddlc-palette) or a plugin installed by its manager (ddlc.nvim) — takes the **partial shape**: steps 1 (VERSION, read by the package or exposed as `lib.version`, with the CI check) and 5–7 minus everything installer-shaped — no completions, no distro tests, no distro badges. The lint dedup and the registry guard apply in full.

## Layout

```
SKILL.md             this file — decisions and the checklist
references/          one spec per piece: install-sh, versioning, completions, distro-tests, ci, readme
templates/           copyable files, mirroring a target repo's paths; @NAME@/@OWNER@/@REPO@ tokens in strings and comments only
check-templates.sh   lints the templates raw, then instantiated with demo values; self-tests against tests/fixtures
tests/fixtures/      known-bad inputs the checkers must fail on
```
