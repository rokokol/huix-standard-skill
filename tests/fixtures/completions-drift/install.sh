#!/usr/bin/env bash
# A fixture for the completion drift check, not an installer. It parses -f beside --force,
# and the completions next to it offer --force alone, so the check has to name -f
#
#   -f, --force   the flag the completions offer only by its long name
usage() { sed -n '2,/^[^#]/p' "${BASH_SOURCE[0]}" | sed '$d; s/^# \{0,1\}//'; }
case "${1:-}" in
  -f | --force) ;;
  -h | --help) usage ;;
esac
