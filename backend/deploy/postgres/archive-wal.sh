#!/bin/sh
# Idempotent, atomic WAL archiver. Args: $1 = %p (source WAL path), $2 = %f (WAL
# file name). Postgres may re-archive the same segment (e.g. after a crash), so
# this returns success if the destination already holds an identical file, fails
# (never overwrites) if it holds a DIFFERENT file, and otherwise copies atomically.
set -eu
src="$1"
dest="/wal-archive/$2"
if [ -f "$dest" ]; then
  if cmp -s "$src" "$dest"; then
    exit 0
  fi
  echo "archive-wal: $2 already exists with different content; refusing to overwrite" >&2
  exit 1
fi
tmp="$dest.tmp.$$"
cp "$src" "$tmp"
mv "$tmp" "$dest"
