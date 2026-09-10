---
name: huix-standard
description: "What it is — a standard for making Nix-flake-first Linux repos installable on any distribution without Nix: a canonical install.sh (flag grammar, version flag, uninstall by manifest, a dependency preflight that never installs anything), tab completion for the installer, and docker-based distro tests that run the installer's own printed guidance, with a badge per distribution. Born in the huix family. Use when adding non-Nix install support to a repo, writing or extending an install.sh or its --uninstall, adding installer completions or distro tests, or bringing a repo up to the huix family standard; version numbers and changelogs belong to the versioning skill, CI workflow doctrine to the ci skill. Triggers: install.sh, install.sh --uninstall, install manifest, dependency preflight, distro tests, huix, huix standard, установщик, установка без nix, дистрибутивы, тесты на дистрибутивах."
license: MIT
---

# huix-standard

A repo in this family is Nix-first: the flake is the source of truth for what the tool needs and how it is configured. `install.sh` is the same mechanism for everyone else — not a second product, but a faithful projection of the flake onto `/usr/local`. This skill is the checklist and the parts box for building that projection the same way every time

Read the reference for the piece you are working on before writing code; copy templates from `templates/` (they mirror the target repo's paths, except `templates/github/`, which lands as `.github/`) and replace `@NAME@` / `@OWNER@` / `@REPO@` tokens. When applying the standard to a repo teaches you something the templates got wrong, fix the template in the same sitting and add a CHANGELOG bullet here — the standard is only real while the repos and the skill agree

## Non-negotiable decisions

These were argued once; do not re-litigate them per repo:

- **One source of version.** The rule, and everything about changelogs and releases, is the [versioning](https://github.com/rokokol/versioning-skill) skill's and is not restated here. What is a family fact: `nix/package.nix` reads the `VERSION` file with `lib.fileContents ../VERSION`, `install.sh -v|--version` prints it, and an installed copy carries it at `share/<name>/VERSION`. See [references/versioning.md](references/versioning.md)
- **Short flags.** Wherever a tool or installer accepts `--help`, `--version`, `--force`, it also accepts `-h`, `-v`, `-f`. Completions update in the same commit — the drift check enforces it
- **One flag per boolean.** Named so its presence flips the default (`--tailscale`, `--no-restore`); never a `--x`/`--no-x` pair. Consequence: install.sh is declarative — each run converges the system to exactly the flags given, and re-running without a flag undoes what the flag did
- **Installer flags mirror only install-affecting options.** Nix module options that change installed artifacts get flags; runtime tunables stay environment variables, documented in a dedicated `--help` section and in the README
- **Dependencies are never installed silently.** The preflight collects everything missing and prints exact per-distro remediation; runnable commands are printed as `  $ command` lines (two spaces, dollar, space) — the distro tests execute exactly those lines, so a typo in the guidance is a red CI run, not an undiscovered lie. AUR counts as official on Arch (`$ paru -S pkg`). Where no official package exists, print the ONE recommended method. See [references/install-sh.md](references/install-sh.md)
- **Uninstall by manifest.** The install writes every path it created (final runtime paths, no DESTDIR) to `share/<name>/install-manifest`; `--uninstall` consumes it. See [references/install-sh.md](references/install-sh.md)
- **bin/ holds a relative symlink** into `share/<name>/` where the script and its data live; the script resolves itself with `readlink -f` and finds data in its own directory. A generated two-line exec wrapper replaces the symlink only when install flags bake environment defaults (the non-Nix analog of `wrapProgram --set-default`)
- **Distro tests run on push to master, weekly cron, and dispatch — never on pull requests.** A flaky mirror must not redden someone's PR; the weekly run on `:latest` images is the upstream-drift detector. Per-distro badges require per-workflow files: one reusable `distro.yml` plus four thin wrappers. See [references/distro-tests.md](references/distro-tests.md)
- **CI doctrine is not duplicated here.** Gate vs detector, pinning, `workflow_call` + `ref`, the bump cascade, one badge per workflow file, falsifiable checks — all of it lives in the [ci](https://github.com/rokokol/ci-skill) skill, and this family follows it whole. What stays a family fact: `build.yml`'s job `nix` runs the VERSION↔CHANGELOG step, `nix build`, `nix flake check`, an `install.sh works` step (under `nix develop` when the preflight demands runtime tools — the runner is not a target distribution) and `nix fmt -- --ci`; job `shell` runs the pin guard and then the one lint command `nix build .#checks.x86_64-linux.scripts-lint`, because **the lint file list lives in the flake's `scripts-lint` check and nowhere else**; and the family's update-lock crons form a wave (palette 05:00 → consumers 06:00 → huix 07:00) so a week of upstream drift flows through in one morning
- **Every check must be able to fail, and that is demonstrated, not assumed.** A new test runs red against the pre-fix state (or a deliberately broken fixture) before the code that turns it green exists. Checkers ship self-tests against known-bad fixtures. Assertions on printed guidance match whole lines (`grep -qxF`), never substrings

## Adoption checklist

Work through this in order when bringing a repo up to standard:

1. `VERSION` file; `nix/package.nix` reads it; `install.sh` gains `-v|--version`; CI gains the VERSION↔CHANGELOG step, the vendored `check-changelog.sh` — run it red first if the repo's versions already disagree ([references/versioning.md](references/versioning.md))
2. `install.sh` reworked onto the canonical skeleton: flag grammar, preflight with `$ `-prefixed guidance, manifest, `--uninstall`, declarative booleans, `--no-systemd` where the repo touches systemd ([references/install-sh.md](references/install-sh.md), template `templates/install.sh`)
3. `completions/install.sh.bash` + `completions/install.sh.zsh` from templates; drift check wired into `scripts-lint` ([references/completions.md](references/completions.md))
4. `tests/distro.sh` from template, adapted; run each distro locally in docker before pushing ([references/distro-tests.md](references/distro-tests.md))
5. Workflows: `distro.yml` + four wrappers; `build.yml` brought to canon (workflow_call+ref, version step, lint deduped into the flake's `scripts-lint`, the pin guard as `./check-pins.sh` — vendored from the ci skill, never edited) — the [ci](https://github.com/rokokol/ci-skill) skill carries the shape and the templates. `distro.yml` and the four `distro-*.yml` wrappers are the only files here a repo keeps byte for byte, so they are vendored rather than copied: `vendor-sync.sh add --manual .github/workflows/distro.yml rokokol/huix-standard-skill templates/github/workflows/distro.yml`, and the same for each wrapper; as workflow files they are manual lines. Every other template is scaffolding the repo owns from the first commit. The mechanism is the ci skill's [vendored files](https://github.com/rokokol/ci-skill/blob/master/references/bump-cascade.md#vendored-files)
6. README: four distro badges after the build badge; document `--uninstall`, completions sourcing, runtime env vars ([references/readme.md](references/readme.md))
7. CHANGELOG bullets for every user-visible change; the layout and build sections of the repo's agent instructions (`CLAUDE.md`, `AGENTS.md` or whatever the agent reads) updated
8. Backport: diff what this repo needed against the templates; generalize the difference into this skill

A repo with no `install.sh` — pure data (ddlc-palette) or a plugin installed by its manager (ddlc.nvim) — takes the **partial shape**: steps 1 (VERSION, read by the package or exposed as `lib.version`, with the CI check) and 5–7 minus everything installer-shaped — no completions, no distro tests, no distro badges. The lint dedup and the registry guard apply in full

## Layout

```
SKILL.md             this file — decisions and the checklist
references/          one spec per piece: install-sh, versioning, completions, distro-tests, readme
templates/           copyable files at a target repo's paths (templates/github/ lands as .github/); @NAME@/@OWNER@/@REPO@ tokens in strings and comments only
check-templates.sh   lints the templates raw and instantiated, runs the installer through a full cycle; self-tests against tests/fixtures
check-skill.sh       the gate every skill repository shares, vendored from the ci skill
check-pins.sh        the pin guard for the workflows, vendored from the ci skill
vendor-sync.sh       keeps the vendored copies byte-equal to their source, vendored from the ci skill
tests/fixtures/      known-bad inputs the checkers must fail on
```
