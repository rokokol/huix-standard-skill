# Distro tests — the printed guidance is the tested guidance

`tests/distro.sh` ([template](../templates/tests/distro.sh)) runs install.sh for real, as root, inside `debian`/`ubuntu`/`archlinux`/`fedora` `:latest` containers. It is the one suite the stub-based `tests/run.sh` cannot replace: a real `/etc`, the real package manager, the real `/etc/os-release` deciding what the preflight says.

## The core idea

When the preflight refuses, the harness extracts every `  $ command` line from the refusal **and runs exactly those lines**. There is no second, hand-maintained copy of the dependency commands — a copy could only disagree with the printed one, and then a typo in the guidance stays green forever. Here a typo is a red weekly run.

The container is root and ships no `sudo`, so the harness answers `sudo` with a two-line `exec "$@"` shim rather than editing the line — a `sudo` can sit mid-pipeline (`| sudo tee …`) where stripping a prefix cannot reach, and an edited line is no longer the line the reader was given. Non-interactivity is likewise arranged around the command, never inside it: `DEBIAN_FRONTEND=noninteractive`, `yes` piped to stdin (a bare newline would read as "No" to dnf). The printed line has no `-y` because a human reads it.

## Sequence (inside the container)

1. **bootstrap** — only what the harness needs in a minimal image, never a dependency the guidance is supposed to provide (that would plant the answer).
2. **relative PREFIX is rejected** — a negative assert that proves the argument validation runs.
3. **install** — if the preflight refuses: the refusal names what is missing, has written nothing, and shows no signs of having carried on past the refusal; then the printed guidance runs; then install must succeed. If everything was already present (some `:latest` images carry a lot), that is stated in the log and the refusal path is exercised by the leaner images.
4. **the installed tool answers** — bin path exists, manifest exists, `--version` matches `VERSION`, `--help` exits 0, plus the repo's `smoke()`.
5. **uninstall** — every manifest path is gone, the share dir is gone, and a second `--uninstall` succeeds quietly (idempotence).

Exit semantics: pass = 0, fail = nonzero. One deliberate green-with-a-mark state: a **required** dep whose guidance on that distro has no runnable `$ ` line at all (genuinely manual method) prints `SKIP`, emits a `::notice`, and exits 0 — GitHub badges have no third color, and red is reserved for the standard's promise breaking. A skip must stay rare: the standard prefers finding the ONE scriptable method per distro.

## AUR policy

AUR counts as official on Arch, so guidance may print `$ paru -S pkg`. The base `archlinux` image has no AUR helper and paru itself lives in AUR, so the harness special-cases `paru -S`: `base-devel` + a throwaway builder user + `makepkg -si --noconfirm` from the package's AUR clone. This path is exercised for real by repos with AUR-only deps (pup), not carried "for the future".

## What the first runs actually caught

Worth knowing what class of bug this suite exists for, because every one of these was green everywhere else:

- a green command read as failed — `yes |` under pipefail turned yes's normal SIGPIPE death into a pipeline failure;
- guidance that could not run — `go install …@latest` resolving a pre-go.mod tag whose fresh dependencies demanded a newer go than Debian ships;
- **a feature probe trusting a proxy** — a script asked `wc -m` whether a locale works, but bash does the counting downstream, and Ubuntu's switch to uutils coreutils made wc answer for a locale bash never got. Probe the mechanism you depend on, never a neighbor;
- **an old tool version behind a `2>/dev/null`** — Debian's jq 1.7 cannot parse `capture(…)?.g`, and the muted compile error read as "no sections". When a distro fails where the rest pass, un-mute the pipeline first.

The pattern: the suite does not test your logic — `tests/run.sh` did that — it tests your assumptions about what a distribution provides.

## Systemd

Containers have no PID-1 systemd. Repos whose install talks to it run the whole container cycle with `--no-systemd` in `INSTALL_FLAGS` — a real install at real paths that skips the live `systemctl` calls, which is precisely the flag's purpose (see [install-sh.md](install-sh.md)).

## CI wiring

One reusable `distro.yml` (`workflow_call`, input `distro`) plus four thin wrappers — see [ci.md](ci.md). Locally: `tests/distro.sh fedora` before trusting a release; the images are large, so it is a deliberate command, not part of `nix flake check`.
