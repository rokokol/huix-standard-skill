# Versioning — one file, everyone reads it

The version lives in exactly one machine-readable place: a `VERSION` file at the repo root, containing `x.y.z` and a trailing newline. Everything else derives from it:

- `nix/package.nix`: `version = lib.fileContents ../VERSION;` (`fileContents` strips the newline).
- `install.sh`: `VERSION=$(cat "$here/VERSION")`, printed by `-v|--version` as `<name> x.y.z`, and installed to `share/<name>/VERSION` so an installed copy knows what it is.
- `CHANGELOG.md` (Keep a Changelog + semver): the current version has a `## [x.y.z]` heading; work in progress goes under `## [Unreleased]`.
- Git tags are `v<x.y.z>`.

## What has no version

A version is a promise to someone who installed a particular one and reports bugs against it. A repository that is only ever *read* at whatever revision is checked out makes no such promise — a skill, a prompt library, a docs-only repo — so it carries no `VERSION` file, no gate and no version badge, and its changelog is dated rather than numbered. This skill is one of those, which is why `check-templates.sh` no longer runs the step on itself; `templates/VERSION` stays, because it is a template for the repos that do ship a version.

## The CI check

`build.yml` carries this step before anything builds:

```sh
ver=$(cat VERSION)
grep -qF "## [$ver]" CHANGELOG.md || {
  echo "VERSION says $ver but CHANGELOG.md has no ## [$ver] heading" >&2
  exit 1
}
```

It exists because the failure it catches has already happened in the family: a repo's package said `1.0` while its tag said `v1.0.1`. When adopting the standard on a repo whose versions already disagree, run the check **before** fixing them — it must go red on the real mismatch. That red run is the check's own falsifiability test; only then align the files.

Tag↔VERSION agreement stays a release-ritual rule (CI would need full history and only fires after the fact): the release commit moves the Unreleased bullets under the new heading **and bumps VERSION in the same commit**, then tags `v<x.y.z>` and cuts a `gh release` whose notes are that section. Put that sentence in the repo's CLAUDE.md CHANGELOG section.
