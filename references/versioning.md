# Versioning — the family's concretes

Where the version lives, which repos have one at all, what a changelog looks like in either case, and how a release is cut belong to the [versioning](https://github.com/rokokol/versioning-skill) skill. It owns those rules and this file does not restate them; what follows is only how the family wires them up

## What the family derives from `VERSION`

- `nix/package.nix`: `version = lib.fileContents ../VERSION;` (`fileContents` strips the newline)
- `install.sh`: `VERSION=$(cat "$here/VERSION")`, printed by `-v|--version` as `<name> x.y.z`, and installed to `share/<name>/VERSION` so an installed copy knows what it is

The standard's own repository has no release version, so its template gate validates only the shape of the seed `templates/VERSION`

## The CI check, and the red run that earns it

`build.yml` validates `VERSION` against `CHANGELOG` before anything builds with `./check-changelog.sh CHANGELOG.md`, vendored from the [versioning](https://github.com/rokokol/versioning-skill) skill through the ci skill's [vendored files](https://github.com/rokokol/ci-skill/blob/master/references/bump-cascade.md#vendored-files) mechanism. It validates the changelog's shape as well as agreement

It exists because the failure it catches has already happened in the family: a repo's package said `1.0` while its tag said `v1.0.1`. When adopting the standard on a repo whose versions already disagree, run the check **before** fixing them — it must go red on the real mismatch. That red run is the check's own falsifiability test; only then align the files

Tag↔VERSION agreement is the versioning skill's as well: checkable once the tag is pushed, while the part no check reaches — putting the tag on the right commit — stays a ritual rule in the repo's own CLAUDE.md, next to the release steps that skill describes
