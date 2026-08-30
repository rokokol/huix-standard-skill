# README additions

The family README shape (centered header, badge stack, `## Contents`, `## Install` with `### Any other distribution`, `## Tests`, `## Layout`) is unchanged; the standard adds to it.

## Badges

The stack keeps its fixed order — tech badges, `Nix-flake`, optional palette/assets, license, then the workflow badges last: `build` first, followed by the four distro badges in the order **debian, ubuntu, arch, fedora**:

```markdown
[![build](https://github.com/OWNER/REPO/actions/workflows/build.yml/badge.svg)](https://github.com/OWNER/REPO/actions/workflows/build.yml)
[![debian](https://github.com/OWNER/REPO/actions/workflows/distro-debian.yml/badge.svg)](https://github.com/OWNER/REPO/actions/workflows/distro-debian.yml)
[![ubuntu](https://github.com/OWNER/REPO/actions/workflows/distro-ubuntu.yml/badge.svg)](https://github.com/OWNER/REPO/actions/workflows/distro-ubuntu.yml)
[![arch](https://github.com/OWNER/REPO/actions/workflows/distro-arch.yml/badge.svg)](https://github.com/OWNER/REPO/actions/workflows/distro-arch.yml)
[![fedora](https://github.com/OWNER/REPO/actions/workflows/distro-fedora.yml/badge.svg)](https://github.com/OWNER/REPO/actions/workflows/distro-fedora.yml)
```

A distro badge reflects the last push-to-master or weekly run — PRs never touch these workflows, so the badge is a statement about master on a current `:latest` image, which is exactly what a visitor wants to know.

## Any other distribution

The section documents, in this order: the `./install.sh` one-liner; that dependencies are never installed silently — the script names what is missing and how to get it; `--uninstall`; the two completion `source` lines; and a short table of the runtime environment variables (the ones `--help`'s Runtime environment section lists), because those are the non-Nix answer to the module's runtime options.

## Tests

`## Tests` mentions `tests/distro.sh <distro>` as locally runnable (needs docker or podman) and that it runs the full preflight→guidance→install→smoke→uninstall cycle.
