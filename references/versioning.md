# Versioning — the family's concretes

Where the version lives, which repos have one at all, what a changelog looks like in either case, and how a release is cut belong to the [versioning](https://github.com/rokokol/versioning-skill) skill. It owns those rules and this file does not restate them; what follows is only how the family wires them up.

## What the family derives from `VERSION`

- `nix/package.nix`: `version = lib.fileContents ../VERSION;` (`fileContents` strips the newline).
- `install.sh`: `VERSION=$(cat "$here/VERSION")`, printed by `-v|--version` as `<name> x.y.z`, and installed to `share/<name>/VERSION` so an installed copy knows what it is.

The consequence visible here: this skill is one of the repos with no version, so it carries no `VERSION` file and `check-templates.sh` does not run the gate on itself.

## The CI check, and the red run that earns it

`build.yml` carries the `VERSION` matches `CHANGELOG` step before anything builds — the shape is in the [ci](https://github.com/rokokol/ci-skill) skill's build template, and `check-changelog.sh` from the versioning skill does the same job and more.

It exists because the failure it catches has already happened in the family: a repo's package said `1.0` while its tag said `v1.0.1`. When adopting the standard on a repo whose versions already disagree, run the check **before** fixing them — it must go red on the real mismatch. That red run is the check's own falsifiability test; only then align the files.

Tag↔VERSION agreement stays a release-ritual rule, which CI cannot gate: put it in the repo's own CLAUDE.md, next to the release steps the versioning skill describes.
