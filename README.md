<div align="center">

# huix-standard skill

**One standard for making Nix-first repos installable everywhere else (≧◡≦)**

[![Agent Skill](https://img.shields.io/badge/Agent_Skill-6E56CF?style=flat)](https://agentskills.io)
![Bash](https://img.shields.io/badge/Bash-4EAA25?style=flat&logo=gnubash&logoColor=white)
![Nix](https://img.shields.io/badge/Nix-flake-7EBAE4?style=flat&logo=nixos&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat&logo=docker&logoColor=white)
[![license](https://img.shields.io/badge/MIT-3DA639?style=flat)](LICENSE)
[![ci](https://github.com/rokokol/huix-standard-skill/actions/workflows/build.yml/badge.svg)](https://github.com/rokokol/huix-standard-skill/actions/workflows/build.yml)

</div>

A Nix-first repo has one honest answer for Nix users and, usually, a hand-written `install.sh` for everyone else that nobody has run on Fedora since spring. This skill is the other half of that promise: `install.sh` as a faithful projection of the flake onto `/usr/local`, built the same way in every repo, and proven on four distributions by containers that execute the installer's own printed guidance

Bring a repo up to standard once and the payoff is that the boring parts stop being decisions — the flag grammar, what a preflight may and may not do, where the uninstall manifest lives, which workflow may gate a pull request. They were argued once and written down, so the next repo inherits the argument instead of repeating it

Born in the [rokokol/huix](https://github.com/rokokol/huix) family, but written to be generic: templates are parameterized with `@NAME@` / `@OWNER@` / `@REPO@` tokens that live only inside strings and comments, so every template lints as-is, and family specifics appear only as worked examples in the references

## Contents

- [Install](#install)
- [What the standard says](#what-the-standard-says)
- [The adoption checklist](#the-adoption-checklist)
- [Tests](#tests)
- [Layout](#layout)

## Install

```sh
git clone https://github.com/rokokol/huix-standard-skill ~/Projects/huix-standard
ln -s ~/Projects/huix-standard ~/.claude/skills/huix-standard
```

Or straight into the skills directory your agent reads:

```sh
git clone https://github.com/rokokol/huix-standard-skill ~/.claude/skills/huix-standard
```

> [!NOTE]
> A skill has no version to pin — it is read at whatever revision you have checked out, so `git pull` is the whole upgrade path

Then ask Claude Code to bring a repo up to standard. [SKILL.md](SKILL.md) carries the decisions and the checklist, `references/` the reasoning, `templates/` the files themselves, laid out along a target repo's own paths so copying is mechanical — except `templates/github/`, which lands as `.github/`

## What the standard says

| | |
|---|---|
| **[One source of version](references/versioning.md)** | A `VERSION` file at the root that `nix/package.nix` reads, `install.sh -v` prints, and CI cross-checks against a matching `CHANGELOG.md` heading — so a release cannot ship with the two disagreeing |
| **[A canonical install.sh](references/install-sh.md)** | `-h/-v` short flags beside the long ones, one flag per boolean named so its presence flips the default, install-affecting Nix options mirrored as flags while runtime tunables stay documented env vars |
| **[A preflight that installs nothing](references/install-sh.md)** | Missing dependencies are collected and reported with exact per-distro remediation, printed as runnable `  $ command` lines — and the distro tests execute those very lines, so a typo in the guidance is a red run rather than an undiscovered lie |
| **[Uninstall by manifest](references/install-sh.md)** | Every path the install creates is written to `share/<name>/install-manifest`, and `--uninstall` consumes it. A run also sweeps paths a previous manifest names that this run did not write, which is what makes re-running without a flag actually undo it |
| **[Completions that cannot drift](references/completions.md)** | Hand-written bash and zsh completion for the installer, sourced from the checkout, held to the installer's parser in both directions by the [bash-best-practices](https://github.com/rokokol/bash-best-practices-skill) skill's `check-sh.sh` in the lint |
| **[Distro tests in real containers](references/distro-tests.md)** | Debian, Ubuntu, Arch and Fedora `:latest`, each running the preflight's own guidance and then the install — on push and weekly, never on pull requests, each with its own badge |
| **[Checks proven able to fail](references/distro-tests.md)** | A new test goes red against the pre-fix state or a deliberately broken fixture before the code that turns it green exists, and assertions on printed guidance match whole lines with `grep -qxF`, never substrings |

CI beyond that shape is not duplicated here — gate versus detector, pinning, `workflow_call` + `ref`, the bump cascade and one badge per workflow file all live in the **[ci](https://github.com/rokokol/ci-skill)** skill, which this family follows whole

## The adoption checklist

The order matters, and [SKILL.md](SKILL.md) spells each step out: `VERSION` and its CI gate → `install.sh` on the canonical skeleton → completions plus the drift check → `tests/distro.sh` run locally in docker → the workflows → the readme's badge row and `--uninstall` docs → changelog bullets → backporting whatever this repo taught you into the templates

A repo with no installer at all — pure data, or a plugin its own manager installs — takes the **partial shape**: the version handling and the CI conventions in full, nothing installer-shaped

> [!IMPORTANT]
> When applying the standard teaches you something the templates got wrong, fix the template in the same sitting. The standard is only real while the repos and the skill agree

## Tests

```sh
nix develop -c ./check-templates.sh
```

Lints every template raw and again instantiated with demo values (proving no `@TOKEN@` survives), runs actionlint over the template workflows and this repository's own, holds the installer template's help and both completion files to its parser with the [bash-best-practices](https://github.com/rokokol/bash-best-practices-skill) skill's `check-sh.sh`, runs the installer template for real through install, reinstall, a staged install and uninstall, holds this repository to the [ci](https://github.com/rokokol/ci-skill) skill's `check-skill.sh` — `SKILL.md` loads, every reference is reached from it, every link and anchor resolves, each proven able to fail on a planted defect — then feeds the checkers their known-bad fixtures from `tests/fixtures/`, and the run fails unless the fixtures do

## Layout

```
SKILL.md             the decisions and the adoption checklist
references/          one spec per piece: install-sh, versioning, completions, distro-tests, readme
templates/           copyable files at a target repo's paths (github/ lands as .github/), @NAME@/@OWNER@/@REPO@ tokens
check-templates.sh   the self-testing template lint
check-skill.sh       the gate every skill repository shares, vendored from the ci skill
check-pins.sh        the pin guard for the workflows, vendored from the ci skill
check-sh.sh          holds the installer template's help and completions to its parser, vendored from the bash-best-practices skill
vendor-sync.sh       keeps the vendored copies byte-equal to their source, vendored from the ci skill
tests/fixtures/      known-bad inputs the checkers must fail on
```
