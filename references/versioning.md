# Versioning — the family's concretes

Where the version lives, which repos have one at all, what a changelog looks like in either case, and how a release is cut belong to the [versioning](https://github.com/rokokol/versioning-skill) skill. It owns those rules and this file does not restate them; what follows is only how the family wires them up

## What the family derives from `VERSION`

- `nix/package.nix`: `version = lib.fileContents ../VERSION;` (`fileContents` strips the newline)
- `install.sh`: `VERSION=$(cat "$here/VERSION")`, printed by `-v|--version` as `<name> x.y.z`, and installed to `share/<name>/VERSION` so an installed copy knows what it is

The consequence visible here: this skill is one of the repos with no version, so it carries no `VERSION` file and `check-templates.sh` does not run the gate on itself

## The CI check, and the red run that earns it

`build.yml` carries the `VERSION` matches `CHANGELOG` step before anything builds, and the step is one line: `./check-changelog.sh CHANGELOG.md`, the versioning skill's checker, taken into the repository as a vendored file — `vendor-sync.sh add check-changelog.sh rokokol/versioning-skill check-changelog.sh`, by the ci skill's [vendored files](https://github.com/rokokol/ci-skill/blob/master/references/bump-cascade.md#vendored-files). It holds the changelog's shape to the rules as well, which the inline grep it replaced never did

It exists because the failure it catches has already happened in the family: a repo's package said `1.0` while its tag said `v1.0.1`. When adopting the standard on a repo whose versions already disagree, run the check **before** fixing them — it must go red on the real mismatch. That red run is the check's own falsifiability test; only then align the files

Tag↔VERSION agreement is the versioning skill's as well: checkable once the tag is pushed, while the part no check reaches — putting the tag on the right commit — stays a ritual rule in the repo's own CLAUDE.md, next to the release steps that skill describes
