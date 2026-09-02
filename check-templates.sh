#!/usr/bin/env bash
# Lints the templates twice — raw (the token rule makes them valid shell/YAML as-is) and
# instantiated with demo values — and then proves the lint can fail at all by feeding it
# the known-bad fixtures. A checker that cannot go red is not a checker.
#
# Needs: shellcheck, shfmt, zsh, actionlint, bash — all taken from PATH; CI provides them
# via nix run, locally a dev shell does
set -euo pipefail

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cd "$HERE"

fail() {
  echo "check-templates: $1" >&2
  exit 1
}

sh_templates=(
  check-templates.sh
  templates/install.sh templates/tests/distro.sh templates/tests/check-completions.sh
)
bash_sourced=(templates/completions/install.sh.bash)
zsh_sourced=(templates/completions/install.sh.zsh)
workflows=(templates/github/workflows/*.yml)

lint_sh() {
  shellcheck "$@"
  shfmt -d -i 2 -ci "$@"
}

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
