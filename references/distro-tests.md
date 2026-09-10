# Distro tests — the printed guidance is the tested guidance

`tests/distro.sh` ([template](../templates/tests/distro.sh)) runs install.sh for real, as root, inside `debian`/`ubuntu`/`archlinux`/`fedora` `:latest` containers. It is the one suite the stub-based `tests/run.sh` cannot replace: a real `/etc`, the real package manager, the real `/etc/os-release` deciding what the preflight says

## The core idea

When the preflight refuses, the harness extracts every `  $ command` line from the refusal **and runs exactly those lines**. There is no second, hand-maintained copy of the dependency commands — a copy could only disagree with the printed one, and then a typo in the guidance stays green forever. Here a typo is a red weekly run

The container is root and ships no `sudo`, so the harness answers `sudo` with a two-line `exec env "$@"` shim rather than editing the line — `env`, so that a line putting `VAR=value` after `sudo` (`sudo GOBIN=… go install …`) still gives the assignment effect — a `sudo` can sit mid-pipeline (`| sudo tee …`) where stripping a prefix cannot reach, and an edited line is no longer the line the reader was given. Non-interactivity is likewise arranged around the command, never inside it, and **what the stdin stream says depends on the package manager's prompt style**: dnf gets `yes` (its `[y/N]` reads an empty answer as No), pacman gets `yes ''` — bare newlines — because its provider-selection menus (`Enter a number (default=1)`, e.g. ffmpeg's jack/libx264 providers) reject `y` as "invalid number" and re-prompt forever, while its `[Y/n]` reads empty as the default yes. Every printed guidance command also runs under `timeout` as the belt for the next prompt style nobody predicted: a red failure, not an unbounded hang filling the log. The `paru -S` arm below is outside it — that one is the harness's own script, `--noconfirm` throughout, rather than a printed line, and the job's own time limit is its only bound. The printed line has no `-y` because a human reads it

## Sequence (inside the container)

1. **bootstrap** — only what the harness needs in a minimal image, never a dependency the guidance is supposed to provide (that would plant the answer)
2. **relative PREFIX is rejected** — a negative assert that proves the argument validation runs
3. **install** — if the preflight refuses: the refusal names what is missing, has written nothing, and shows no signs of having carried on past the refusal; then the printed guidance runs; then install must succeed. If everything was already present (some `:latest` images carry a lot), that is stated in the log and the refusal path is exercised by the leaner images
4. **the installed tool answers** — bin path exists, manifest exists, the installed `share/<name>/VERSION` equals `VERSION`, the installed tool's own `--version` prints it as a whole word (1.0 must not pass against 1.0.1), `--help` exits 0, plus the repo's `smoke()`
5. **uninstall** — every manifest path is gone, the share dir is gone, and a second `--uninstall` succeeds quietly (idempotence)

Exit semantics: pass = 0, fail = nonzero. One deliberate green-with-a-mark state: a **required** dep whose guidance on that distro has no runnable `$ ` line at all (genuinely manual method) prints `SKIP`, emits a `::notice`, and exits 0 — GitHub badges have no third color, and red is reserved for the standard's promise breaking. A skip must stay rare: the standard prefers finding the ONE scriptable method per distro

## AUR policy

AUR counts as official on Arch, so guidance may print `$ paru -S pkg`. The base `archlinux` image has no AUR helper and paru itself lives in AUR, so the harness special-cases `paru -S` with the documented equivalent: `base-devel` + a throwaway builder (makepkg refuses root, and its own sudo calls would hit our shim), the package's depends read from its PKGBUILD and installed by pacman, `makepkg --noconfirm` **without** `-si`, then `pacman -U` as root. This path is exercised for real by repos with AUR-only deps (pup), not carried "for the future"

## What the first runs actually caught

Worth knowing what class of bug this suite exists for, because every one of these was green everywhere else:

- a green command read as failed — `yes |` under pipefail turned yes's normal SIGPIPE death into a pipeline failure;
- guidance that could not run — `go install …@latest` resolving a pre-go.mod tag whose fresh dependencies demanded a newer go than Debian ships;
- **a feature probe trusting a proxy** — a script asked `wc -m` whether a locale works, but bash does the counting downstream, and Ubuntu's switch to uutils coreutils made wc answer for a locale bash never got. Probe the mechanism you depend on, never a neighbor;
- **an old tool version behind a `2>/dev/null`** — Debian's jq 1.7 cannot parse `capture(…)?.g`, and the muted compile error read as "no sections". When a distro fails where the rest pass, un-mute the pipeline first;
- **a prompt the answer stream cannot answer** — pacman's provider menu rejected `yes`'s `y` as "invalid number" and re-prompted forever, growing a 9 GB log before anyone looked (virtual-media-devices' ffmpeg pulling jack). Hence the per-manager answer stream and the `timeout` belt above: an interactive loop must become a red failure, never a hang

The pattern: the suite does not test your logic — `tests/run.sh` did that — it tests your assumptions about what a distribution provides

One portability rule for the assertions themselves: no empty alternation in ERE — `(a|b|)$` is rejected outright by some grep implementations (ugrep; POSIX calls it undefined). Spell the empty case explicitly, e.g. `[[:space:]]*` for a blank line

And one more surface the suite ends up testing: **the observer's own network topology**. A download that fails inside the container but succeeds from the host (`curl -sI <url>` is the one-line probe) is the network, not the repo — Docker's default bridge egresses directly, bypassing host VPN routing, so a geo-blocking CDN can 403 the container while answering the host 200 (met live: Fedora's `ffmpeg-free` pulling openh264 from Cisco's CloudFront). Verify the cycle locally with `--network host` (`docker run --rm --network host -v "$REPO:/src:ro" <image> bash /src/tests/distro.sh --inside <distro>`); CI runners egress elsewhere and stay the source of truth for that distro

## Systemd

Containers have no PID-1 systemd. Repos whose install talks to it run the whole container cycle with `--no-systemd` in `INSTALL_FLAGS` — a real install at real paths that skips the live `systemctl` calls, which is precisely the flag's purpose (see [install-sh.md](install-sh.md))

## Docker-in-Docker for network integrations

DinD is not part of the generic template. Add it when the product explicitly promises that container traffic works through a VPN, TUN or routing policy: a CLI's ordinary install cycle gains nothing from a second daemon. Keep Docker in a separate `DIND_INSTALL` map as a harness dependency — never hide it in the product preflight or install it before that preflight has proved its own guidance

The outer distro container needs `--privileged`. Give its inner daemon a private socket, data root, exec root and address pool, and use `--storage-driver vfs`: the outer container normally has an overlay filesystem, so an inner overlay driver fails with `invalid argument`. Pull the inner image before activating a deliberately blocking proxy/TUN; otherwise the test blocks its own fixture setup instead of exercising container traffic. Use `ubuntu:latest`, consistently with the `:latest` outer images, when Ubuntu repository access is the assertion

Firewall implementations differ even when every package calls the executable `docker`. Fedora's current `moby-engine` selects legacy iptables, which can see no legacy `nat` table in a DinD namespace. Docker 29 can instead start with `--firewall-backend=nftables`; feature-detect that flag from `dockerd --help` so older Docker versions on the other distributions keep working. Print the daemon log when startup dies, retry registry pulls once, and stop both dockerd and the routing process on success or failure

The routing assertion must cover the mechanism users rely on, not merely `docker0`. Docker's default bridge has a stable name, but user-defined Compose networks get dynamic `br-*` names; reserve a test address pool in the installed policy and create traffic on an inner bridge from that pool. Where a consumer cannot express interface globs, match dynamic bridge names in the host firewall rather than pretending `exclude_interface = [ "br-*" ]` is a wildcard

## CI wiring

One reusable `distro.yml` (`workflow_call`, input `distro`) plus four thin wrappers — one badge is one workflow file, per the [ci](https://github.com/rokokol/ci-skill) skill. Locally: `tests/distro.sh fedora` before trusting a release; the images are large, so it is a deliberate command, not part of `nix flake check`
