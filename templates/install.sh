#!/usr/bin/env bash
# Installer for @NAME@ on systems without Nix. Projects what nix/package.nix installs onto
# a plain prefix: the script and its data under share/@NAME@, a relative symlink in bin,
# and an install-manifest that --uninstall consumes.
#
# Template from huix-standard. Replace the EXAMPLE blocks (marked >>> / <<<) with the
# repo's own dependencies, flags and files; everything outside the markers is the standard
set -euo pipefail

here="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
VERSION=$(cat "$here/VERSION")

PREFIX="${PREFIX:-/usr/local}"
DESTDIR="${DESTDIR:-}"
OS_RELEASE="${OS_RELEASE:-/etc/os-release}"

usage() {
  cat <<EOF
install @NAME@ $VERSION into a prefix

Each run converges the prefix to exactly the flags given: re-running without a flag
undoes what that flag installed, the way unsetting a Nix option does on rebuild.

usage: ./install.sh [options]
  -h, --help        show this help and exit
  -v, --version     print the version and exit
      --prefix DIR  install prefix (default: $PREFIX; env PREFIX)
      --destdir DIR staging root: files land under DESTDIR/PREFIX and no live
                    system state is touched (env DESTDIR)
      --uninstall   remove everything a previous install wrote, by its manifest

Runtime environment (read by the installed tool, not this script):
  EXAMPLE_VAR       what it tunes (default: value)
EOF
}

UNINSTALL=0
config_given=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    -v | --version)
      echo "@NAME@ $VERSION"
      exit 0
      ;;
    --prefix)
      PREFIX="${2:?directory required by $1}"
      shift 2
      ;;
    --destdir)
      DESTDIR="${2:?directory required by $1}"
      shift 2
      ;;
    --uninstall)
      UNINSTALL=1
      shift
      ;;
    # >>> EXAMPLE repo-specific flags: one per install-affecting Nix option. Booleans are
    # single flags that flip the default; value flags guard with ${2:?...}. Set
    # config_given="$1" so --uninstall can refuse the combination
    # <<<
    *)
      usage >&2
      exit 1
      ;;
  esac
done

if [[ "$PREFIX" != /* ]]; then
  echo "install.sh: PREFIX must be absolute: $PREFIX" >&2
  exit 1
fi
if ((UNINSTALL)) && [[ -n "$config_given" ]]; then
  echo "install.sh: --uninstall does not combine with $config_given" >&2
  exit 1
fi

root="${DESTDIR%/}$PREFIX"
share_runtime="$PREFIX/share/@NAME@"
share="${DESTDIR%/}$share_runtime"
manifest="$share/install-manifest"

# --- manifest helpers ------------------------------------------------------------------
# Every path the install creates is recorded as its final runtime path (no DESTDIR): the
# manifest ships inside a staged tree and stays correct wherever the tree ends up.
# Paths a previous install wrote that this run does not are swept before the new
# manifest lands — that sweep is what makes the flags declarative

old_paths=()
if [[ -f "$manifest" ]]; then
  mapfile -t old_paths < <(grep -v '^#' "$manifest")
fi

installed=()

put() { # put MODE SRC RUNTIME_DST — install one file and record it
  install -D -m "$1" "$2" "${DESTDIR%/}$3"
  installed+=("$3")
}

lnk() { # lnk TARGET RUNTIME_DST — relative symlink into share, recorded
  install -d "$(dirname "${DESTDIR%/}$2")"
  ln -sfn "$1" "${DESTDIR%/}$2"
  installed+=("$2")
}

prune() { # remove now-empty parents of RUNTIME_PATH, stopping below the prefix's own dirs
  # bin/, share/, etc/ belong to the prefix, not to this install: a shell profile may put
  # ~/.local/bin on PATH only when it exists, so they stay even when empty
  local dir
  dir="$(dirname "${DESTDIR%/}$1")"
  while [[ "$dir" == "$root"/*/* ]]; do
    rmdir "$dir" 2>/dev/null || break
    dir="$(dirname "$dir")"
  done
}

# --- uninstall -------------------------------------------------------------------------

if ((UNINSTALL)); then
  if [[ ! -f "$manifest" ]]; then
    # >>> EXAMPLE fallback: for exactly one release after adopting the standard, remove
    # the pre-standard fixed path list here, so installs made before the manifest existed
    # can still be taken out. Delete this arm in the release after that
    # <<<
    echo "@NAME@: nothing to uninstall under $root"
    exit 0
  fi
  # >>> EXAMPLE live undo: disable timers/units, restore saved sysctl values — everything
  # the install changed outside the prefix — before the files go, and only when DESTDIR
  # is empty (a staged tree has no live state)
  # <<<
  while IFS= read -r path; do
    [[ -z "$path" || "$path" == \#* ]] && continue
    rm -f "${DESTDIR%/}$path"
    prune "$path"
  done <"$manifest"
  rm -f "$manifest"
  rmdir "$share" 2>/dev/null || true
  echo "uninstalled @NAME@ from $root"
  exit 0
fi

# --- preflight: refuse loudly, install nothing ----------------------------------------
# install deps: the installer or the artifact cannot exist without them — any missing
# means collect them all, print the report, exit 1 having written nothing.
# session deps: supplied by the user's live session — one warning each, install proceeds

missing=()
absent=()

need() { command -v "$1" >/dev/null 2>&1 || missing+=("$1"); }
want() { command -v "$1" >/dev/null 2>&1 || absent+=("$1"); }

need install
need mktemp
# >>> EXAMPLE deps: need every install dep, want every session dep (hyprctl, rofi...)
# <<<

distro_id() {
  sed -n 's/^ID\(_LIKE\)\?=//p' "$OS_RELEASE" 2>/dev/null | tr -d '"' | tr '\n' ' '
}

guidance() {
  # One recommended method per distro. Runnable lines are printed as `  $ command` —
  # two spaces, dollar, space — and the distro tests run exactly those lines, so this
  # text cannot rot silently. Prose and bare URLs are indented without the `$ `.
  # No -y/--noconfirm here: a human is reading; the tests arrange non-interactivity
  # around the command, never inside it
  case " $(distro_id) " in
    *" arch "*)
      echo "Install them on Arch:"
      echo '  $ sudo pacman -S --needed EXAMPLE-PKG'
      ;;
    *" debian "* | *" ubuntu "*)
      echo "Install them on Debian/Ubuntu:"
      echo '  $ sudo apt install EXAMPLE-PKG'
      ;;
    *" fedora "*)
      echo "Install them on Fedora:"
      echo '  $ sudo dnf install EXAMPLE-PKG'
      ;;
    *)
      echo "Install them with your package manager:"
      echo "  https://example.invalid/EXAMPLE-PKG"
      ;;
  esac
}

if ((${#missing[@]})); then
  {
    echo "install.sh: missing dependencies:"
    printf '  - %s\n' "${missing[@]}"
    echo
    guidance
  } >&2
  exit 1
fi
if ((${#absent[@]})); then
  printf 'install.sh: not found (comes from your session, install proceeds): %s\n' \
    "${absent[@]}" >&2
fi

# --- install ---------------------------------------------------------------------------

# >>> EXAMPLE files: script and data into share, a relative symlink in bin, completions
# for the tool. When an install flag bakes an env default, the symlink becomes a generated
# wrapper: take the recipe from huix-standard's references/install-sh.md, which removes
# the symlink first (writing through it overwrites the real script) and quotes the value
put 755 "$here/@NAME@.sh" "$share_runtime/@NAME@.sh"
lnk "../share/@NAME@/@NAME@.sh" "$PREFIX/bin/@NAME@"
# <<<
put 644 "$here/VERSION" "$share_runtime/VERSION"

# The declarative sweep: whatever the previous install wrote and this one did not
for path in "${old_paths[@]}"; do
  keep=0
  for now in "${installed[@]}"; do
    [[ "$path" == "$now" ]] && keep=1
  done
  ((keep)) || rm -f "${DESTDIR%/}$path"
done

{
  echo "# @NAME@ $VERSION install manifest"
  printf '%s\n' "${installed[@]}"
} >"$manifest"

echo "installed @NAME@ $VERSION into $root (manifest: $manifest)"
