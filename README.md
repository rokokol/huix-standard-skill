<div align="center">

# huix-standard

**One standard for making Nix-first repos installable everywhere else (≧◡≦)**

![Bash](https://img.shields.io/badge/Bash-4EAA25?logo=gnubash&logoColor=white)
![Nix flake](https://img.shields.io/badge/Nix-flake-7EBAE4?logo=nixos&logoColor=white)
[![license](https://img.shields.io/badge/code-MIT-3DA639)](LICENSE)
[![ci](https://github.com/rokokol/huix-standard/actions/workflows/ci.yml/badge.svg)](https://github.com/rokokol/huix-standard/actions/workflows/ci.yml)

</div>

A [Claude Code skill](https://docs.anthropic.com/en/docs/claude-code) that standardizes how a Nix-flake-first Linux repo supports every other distribution: a canonical `install.sh` with a version, an uninstall that consumes its own install manifest, a dependency preflight that never installs anything silently, tab completion for the installer, docker-based distro tests for Debian/Ubuntu/Arch/Fedora with per-distro CI badges, and one deduplicated lint/CI shape.

Born in the [rokokol/huix](https://github.com/rokokol/huix) family of repos, but written to be generic: the templates are parameterized (`@NAME@`, `@OWNER@`, `@REPO@` — tokens live only inside strings and comments, so every template lints as-is), and family specifics appear only as examples in the references.

## Contents

- [Use as a skill](#use-as-a-skill)
- [What the standard says](#what-the-standard-says)
- [Tests](#tests)
- [Layout](#layout)

## Use as a skill

Clone and symlink into your skills directory:

```sh
git clone https://github.com/rokokol/huix-standard ~/Projects/huix-standard
ln -s ~/Projects/huix-standard ~/.claude/skills/huix-standard
```

Then ask Claude Code to bring a repo up to standard — [SKILL.md](SKILL.md) carries the adoption checklist and the decisions; `references/` carries the reasoning; `templates/` carries the files, mirroring a target repo's paths so copying is mechanical.

## What the standard says

The short version — each line links to the full spec:

- [One `VERSION` file](references/versioning.md) read by the flake, the installer and CI; the CHANGELOG must have a heading for it.
- [A canonical install.sh](references/install-sh.md): `-h/-v` (and `-f` where `--force` exists), declarative single-flag booleans, install-affecting Nix options as flags and runtime tunables as documented env vars, a preflight that refuses loudly with runnable `$ `-prefixed per-distro guidance, and `--uninstall` by manifest.
- [Hand-written completions for install.sh](references/completions.md), sourced from the checkout, kept honest by a drift check.
- [Distro tests](references/distro-tests.md) that run the preflight's own printed commands inside `:latest` containers — the guidance cannot rot silently.
- [CI](references/ci.md): one reusable distro workflow plus four badge-bearing wrappers (push to master + weekly, never on PRs), a build.yml that update-lock can actually call, and a single lint file list owned by the flake.
- Every check is proven able to fail — red first against a bad fixture or the pre-fix state, green second.

## Tests

```sh
./check-templates.sh
```

Lints every template raw and instantiated, runs actionlint over the workflows, and then feeds the lint its known-bad fixtures from `tests/fixtures/` — the run fails unless the fixtures do.

## Layout

```
SKILL.md             the checklist and the decisions
references/          one spec per piece: install-sh, versioning, completions, distro-tests, ci, readme
templates/           copyable files mirroring a target repo's paths
check-templates.sh   the self-testing template lint
tests/fixtures/      known-bad inputs the lint must fail on
```
