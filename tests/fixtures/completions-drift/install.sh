#!/usr/bin/env bash
# A fixture for the completion drift check, not an installer. It parses -f beside --force,
# and the completions next to it offer --force alone, so the check has to name -f
case "${1:-}" in
  -f | --force)
    ;;
  -h | --help)
    ;;
esac
