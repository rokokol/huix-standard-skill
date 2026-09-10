#!/usr/bin/env bash
# Drift check: every flag install.sh parses must appear in both completion files, and
# every long flag a completion offers must exist in install.sh. The completion lists are
# hand-written on purpose — this is what keeps them honest.
#
# Runs from scripts-lint / tests/run.sh. Exits nonzero naming each missing flag.
#
# Template from huix-standard — usually needs no per-repo edits
set -euo pipefail

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO="${1:-$(dirname "$HERE")}"

installer="$REPO/install.sh"
bash_comp="$REPO/completions/install.sh.bash"
zsh_comp="$REPO/completions/install.sh.zsh"

for f in "$installer" "$bash_comp" "$zsh_comp"; do
  [[ -f "$f" ]] || {
    echo "check-completions: missing $f" >&2
    exit 1
  }
done

# Flags are the tokens of install.sh's case patterns: lines like `-h | --help)` and
# `--prefix)`. Anything matching a pattern line is split on | into individual flags
mapfile -t flags < <(
  sed -n 's/^ *\(-[-a-zA-Z0-9 |]*\))$/\1/p' "$installer" |
    tr '|' '\n' | tr -d ' ' | sort -u
)
((${#flags[@]})) || {
  echo "check-completions: found no flags in $installer — the extractor is broken" >&2
  exit 1
}

# A flag has to appear as a token of its own. A substring match let `-f` pass on a completion
# that offered only `--force`, and `-h` on one that offered only `--help`, so a missing short
# flag always passed whenever its long twin was present. The hyphen counts as part of the
# token on purpose: `grep -w` treats it as a separator, and would accept `--help` inside
# `--help-all`
offers() { # offers FILE FLAG -> 0 when FILE names FLAG as a whole token
  grep -qE -- "(^|[^[:alnum:]_-])$2([^[:alnum:]_-]|\$)" "$1"
}

fails=0
for flag in "${flags[@]}"; do
  offers "$bash_comp" "$flag" || {
    echo "check-completions: $flag is parsed by install.sh but absent from ${bash_comp##*/}" >&2
    fails=$((fails + 1))
  }
  offers "$zsh_comp" "$flag" || {
    echo "check-completions: $flag is parsed by install.sh but absent from ${zsh_comp##*/}" >&2
    fails=$((fails + 1))
  }
done

# The reverse direction: a completion must not advertise a flag the installer dropped
mapfile -t offered < <(
  grep -ohE -- '--[a-z][a-z0-9-]+' "$bash_comp" "$zsh_comp" | sort -u
)
for flag in "${offered[@]}"; do
  found=0
  for known in "${flags[@]}"; do
    [[ "$flag" == "$known" ]] && found=1
  done
  ((found)) || {
    echo "check-completions: $flag is offered by a completion but not parsed by install.sh" >&2
    fails=$((fails + 1))
  }
done

((fails == 0)) || exit 1
echo "check-completions: install.sh and both completions agree (${#flags[@]} flags)"
