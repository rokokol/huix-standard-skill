#!/usr/bin/env bash
# Lints the templates twice — raw (the token rule makes them valid shell/YAML as-is) and
# instantiated with demo values — and then proves the lint can fail at all by feeding it
# the known-bad fixtures. A checker that cannot go red is not a checker.
#
# Needs: shellcheck, shfmt, zsh, actionlint, bash — from the flake's dev shell, locally and
# in CI alike, never from PATH's luck:
#
#   nix develop -c ./check-templates.sh
set -euo pipefail

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cd "$HERE"

fail() {
  echo "check-templates: $1" >&2
  exit 1
}

# The gate's own scripts, linted but never instantiated: they carry no tokens, only the
# sed that replaces them. check-skill.sh is copied verbatim from the ci skill
gate=(check-templates.sh check-skill.sh)
sh_templates=(templates/install.sh templates/tests/distro.sh templates/tests/check-completions.sh)
bash_sourced=(templates/completions/install.sh.bash)
zsh_sourced=(templates/completions/install.sh.zsh)
workflows=(templates/github/workflows/*.yml)

lint_sh() {
  shellcheck "$@"
  shfmt -d -i 2 -ci "$@"
}

echo "== the gate's own scripts lint"
lint_sh "${gate[@]}"

echo "== raw templates lint as-is (tokens live only in strings and comments)"
lint_sh "${sh_templates[@]}"
shellcheck --shell=bash "${bash_sourced[@]}"
shfmt -d -i 2 -ci "${bash_sourced[@]}"
for f in "${zsh_sourced[@]}"; do
  zsh -n "$f"
done

echo "== instantiated templates still lint, and no token survives instantiation"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
instantiate() {
  sed 's/@NAME@/demo/g; s/@OWNER@/acme/g; s/@REPO@/demo-repo/g' "$1" >"$2"
}
for f in "${sh_templates[@]}" "${bash_sourced[@]}" "${zsh_sourced[@]}" "${workflows[@]}"; do
  mkdir -p "$work/$(dirname "$f")"
  instantiate "$f" "$work/$f"
  leftover=$(grep -oE '@[A-Z]+@' "$work/$f" | sort -u || true)
  [[ -z "$leftover" ]] || fail "unknown token(s) in $f: $leftover"
done
(cd "$work" && lint_sh "${sh_templates[@]}")
for f in "${sh_templates[@]}"; do
  bash -n "$work/$f"
done
(cd "$work" && shellcheck --shell=bash "${bash_sourced[@]}")
for f in "${zsh_sourced[@]}"; do
  zsh -n "$work/$f"
done

echo "== workflows pass actionlint"
mkdir -p "$work/.github/workflows"
for f in "${workflows[@]}"; do
  instantiate "$f" "$work/.github/workflows/$(basename "$f")"
done
(cd "$work" && actionlint .github/workflows/*.yml)

echo "== this repository's own workflows are valid, and their tools come from the lock rather than a registry"
# The same guard the build.yml template hands out, applied here so it runs locally too
# rather than only as a step in ci.yml
actionlint
if grep -rEn 'nix (run|shell) nixpkgs#' .github/workflows; then
  fail "an unpinned registry lookup in a workflow — pin the tool in the flake's dev shell and use nix develop"
fi

echo "== the completion drift check agrees with the templates it ships beside"
# The one template that can be executed here rather than only linted: run it on the
# template installer and completions, exactly as a target repository runs it on its own
bash templates/tests/check-completions.sh "$PWD/templates"

echo "== templates/VERSION is the x.y.z a new repository starts from"
# Its shape is all it can be checked against: it is not this repository's version (a skill
# has none) and no changelog records it — it is the seed a target repository copies and
# then owns, and that repository's own VERSION↔CHANGELOG check takes over from there
grep -qxE '[0-9]+\.[0-9]+\.[0-9]+' templates/VERSION ||
  fail "templates/VERSION is not an x.y.z: '$(cat templates/VERSION)'"

echo "== this repository passes the gate every skill repository shares"
# SKILL.md loads, every reference is reached from it, every link and anchor resolves —
# and check-skill.sh proves each of those able to fail on a planted defect as it runs
./check-skill.sh -n huix-standard .

echo "== the lint can fail: known-bad fixtures must go red"
if lint_sh tests/fixtures/must-fail.sh >/dev/null 2>&1; then
  fail "the shell lint passed tests/fixtures/must-fail.sh — it cannot catch anything"
fi
bad=$(mktemp -d)
mkdir -p "$bad/.github/workflows"
cp tests/fixtures/must-fail.yml "$bad/.github/workflows/"
if (cd "$bad" && actionlint .github/workflows/*.yml >/dev/null 2>&1); then
  rm -rf "$bad"
  fail "actionlint passed tests/fixtures/must-fail.yml — it cannot catch anything"
fi
rm -rf "$bad"

echo
echo "check-templates: everything holds"
