#!/usr/bin/env bash
# Atomically switches the active deployment (Task 6, Phase 7-A infra/ops
# foundation -- design doc §5.3/§5.4/§6.5).
#
# Run from the deployment base directory (e.g. /opt/peppercheck) that
# contains `deployments/<id>/` (one dir per shipped release, staged by the
# deploy workflow, Task 10) plus the `current`/`previous` symlink/file pair
# maintained by this script:
#
#   deployments/
#     <sha>-<run_id>/   ...
#   current  -> deployments/<id>      (symlink; the live deployment)
#   previous                          (plain file containing the prior id,
#                                      for rollback -- `switch-deployment.sh
#                                      "$(cat previous)"`)
#
# A bare `ln -sfn` over an existing symlink is NOT atomic (unlink + create
# are two syscalls -- a reader can observe a missing `current` in between).
# The atomic-swap idiom is: point a throwaway symlink at the new target,
# then `mv -Tf` it over `current` in one rename(2) syscall.
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: switch-deployment.sh <id>" >&2
  exit 1
fi

id="$1"

# The id ends up as a path component (`deployments/<id>`) and is recorded
# verbatim in `previous`, so keep it to a safe, unambiguous charset -- no
# `/`, no `..`, no empty string. Real ids are `<sha>-<run_id>` (Task 10).
case "$id" in
  '' | *[!A-Za-z0-9._-]* | .* | *..*)
    echo "switch-deployment: invalid id '$id'" >&2
    exit 1
    ;;
esac

target="deployments/${id}"
if [ ! -d "$target" ]; then
  echo "switch-deployment: $target does not exist" >&2
  exit 1
fi

# Record the id `current` points at *today* as `previous`, before touching
# `current`. On the very first deploy there is no existing `current`, so
# there is nothing to record.
if [ -L current ]; then
  basename "$(readlink current)" > previous
fi

tmp_link="current.tmp.$$"
trap 'rm -f "$tmp_link"' EXIT

ln -sfn "$target" "$tmp_link"
mv -Tf "$tmp_link" current
