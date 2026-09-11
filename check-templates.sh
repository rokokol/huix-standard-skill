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
# sed that replaces them. check-skill.sh, check-pins.sh and vendor-sync.sh are vendored
# from the ci skill
gate=(check-templates.sh check-sh.sh check-skill.sh check-pins.sh vendor-sync.sh)
sh_templates=(templates/install.sh templates/tests/distro.sh)
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

echo "== this repository's own workflows are valid, and no workflow here or in the templates reaches a registry"
# The pin guard the build.yml template hands out, vendored from the ci skill. It proves on
# every run that it catches each unpinned shape, then scans both this repository's
# workflows and the template ones — the templates are workflows too. Every vendored copy
# must still be the blob .github/vendor.lock records, so one edited here fails by name
actionlint
./vendor-sync.sh check
./check-pins.sh .github/workflows templates/github/workflows

echo "== the installer's help and completions agree with its parser, by the bash-best-practices checker"
# check-sh.sh, vendored from the bash-best-practices skill, holds the template installer's
# help to its flags and exit codes and both completion files to its parser in both
# directions — exactly as a target repository runs it on its own, from scripts-lint. It
# plants its own defects on every run, so nothing here has to prove it can fail
./check-sh.sh -c templates/completions/install.sh.bash templates/completions/install.sh.zsh templates/install.sh
# Still, the one defect this repository once let through is kept as a fixture: a substring
# match let every short flag pass whenever its long twin was present, and the fixture
# offers --force and never -f
if out=$(./check-sh.sh -n install.sh -c tests/fixtures/completions-drift/completions/install.sh.bash tests/fixtures/completions-drift/completions/install.sh.zsh tests/fixtures/completions-drift/install.sh 2>&1); then
  fail "the completion drift check passed completions that never offer -f — a missing short flag goes unseen"
fi
grep -qF -- '-f is parsed by install.sh but absent' <<<"$out" ||
  fail "the completion drift check failed the drift fixture for the wrong reason: $out"

echo "== the installer template installs, reinstalls, stages and uninstalls for real"
# Lint says the template parses; only running it says it installs. The demo repository is
# the template instantiated beside a stand-in tool, and the prefix starts with an empty
# bin/ of its own — what ~/.local/bin looks like before anything lands in it, and what a
# shell profile tests for before putting it on PATH — so the uninstall must leave it
demo="$work/run"
mkdir -p "$demo/repo" "$demo/prefix/bin"
instantiate templates/install.sh "$demo/repo/install.sh"
chmod +x "$demo/repo/install.sh"
cp templates/VERSION "$demo/repo/VERSION"
version="demo $(cat templates/VERSION)"
printf '#!/bin/sh\necho "%s"\n' "$version" >"$demo/repo/demo.sh"
run_install() { "$demo/repo/install.sh" --prefix "$demo/prefix" "$@" >/dev/null; }
manifest="$demo/prefix/share/demo/install-manifest"

run_install || fail "the installer template failed a plain install"
[[ "$("$demo/prefix/bin/demo")" == "$version" ]] ||
  fail "the installed entry point does not run the tool"
[[ "$("$demo/repo/install.sh" --version)" == "$version" ]] ||
  fail "install.sh --version does not print '$version'"
first=$(cat "$manifest")
run_install || fail "the installer template failed to reinstall over itself"
[[ "$(cat "$manifest")" == "$first" ]] ||
  fail "a reinstall with the same flags changed the manifest"
mapfile -t paths < <(grep -v '^#' "$manifest")
run_install --uninstall || fail "the installer template failed to uninstall"
for path in "${paths[@]}"; do
  [[ ! -e "$path" && ! -L "$path" ]] || fail "uninstall left $path behind"
done
[[ ! -e "$demo/prefix/share/demo" ]] || fail "uninstall left share/demo behind"
[[ -d "$demo/prefix/bin" ]] ||
  fail "uninstall removed the prefix's own bin/, which the install never created"
run_install --uninstall || fail "a second uninstall is not a quiet success"

# Staged: files land under DESTDIR, the manifest names the paths they will have at runtime
run_install --destdir "$demo/stage" || fail "the installer template failed a staged install"
[[ -L "$demo/stage$demo/prefix/bin/demo" ]] || fail "a staged install put no bin entry under DESTDIR"
if grep -qF -- "$demo/stage" "$demo/stage$manifest"; then
  fail "a staged manifest records DESTDIR paths instead of runtime ones"
fi

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
# One tool at a time: inside an `if` errexit is suspended, so `lint_sh` there would
# report shfmt's status alone and a shellcheck that passes everything would go unseen
if shellcheck tests/fixtures/must-fail.sh >/dev/null 2>&1; then
  fail "shellcheck passed tests/fixtures/must-fail.sh — it cannot catch anything"
fi
if shfmt -d -i 2 -ci tests/fixtures/must-fail.sh >/dev/null 2>&1; then
  fail "shfmt passed tests/fixtures/must-fail.sh — it cannot catch anything"
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
