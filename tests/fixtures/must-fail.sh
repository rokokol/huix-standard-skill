#!/usr/bin/env bash
# A known-bad shell file: the quote below is never closed. check-templates.sh runs its
# lint pipeline on this and demands a failure — a pipeline that passes this would also
# pass a broken template, and its green runs would mean nothing
echo "this quote never closes
