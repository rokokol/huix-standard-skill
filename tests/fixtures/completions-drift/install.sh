#!/usr/bin/env bash
usage() {
  cat <<'EOF'
A fixture for the completion drift check, not an installer. It parses -f beside --force,
and the completions next to it offer --force alone, so the check has to name -f

  -f, --force   the flag the completions offer only by its long name
EOF
}
case "${1:-}" in
  -f | --force) ;;
  -h | --help) usage ;;
esac
