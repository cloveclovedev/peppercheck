#!/usr/bin/env bash
# Enforces import boundaries in the Flutter app:
#   1. firebase_auth may only be imported under lib/features/auth/.
#   2. supabase_flutter must not be imported by the features already migrated
#      off it: features/auth, features/profile, features/notification, or by
#      core/network.
#   3. Dio is only constructed in core/network — features must go through
#      ApiClient/PresignedUploadClient, never build their own Dio instance.
# evidence still builds Dio directly for R2 uploads until its own migration
# phase (Phase 4b); it is deliberately excluded from rule 3 until then.
set -euo pipefail
cd "$(dirname "$0")/.."
lib=peppercheck_flutter/lib
fail=0

bad_fb=$(grep -rl "package:firebase_auth/" "$lib" \
  | grep -v "^$lib/features/auth/" || true)
if [ -n "$bad_fb" ]; then
  echo "ERROR: firebase_auth imported outside lib/features/auth/:"
  echo "$bad_fb"
  fail=1
fi

bad_sb=$(grep -rl "package:supabase_flutter/" \
  "$lib/features/auth" "$lib/features/profile" "$lib/features/notification" \
  "$lib/core/network" || true)
if [ -n "$bad_sb" ]; then
  echo "ERROR: supabase_flutter imported on a migrated path (features/auth, features/profile, features/notification, core/network):"
  echo "$bad_sb"
  fail=1
fi

bad_dio=$(grep -rlE "Dio\(|Dio\.new" "$lib" \
  | grep -v "^$lib/core/network/" \
  | grep -v "^$lib/features/evidence/" || true)
if [ -n "$bad_dio" ]; then
  echo "ERROR: Dio constructed outside core/network (features must use ApiClient/PresignedUploadClient):"
  echo "$bad_dio"
  fail=1
fi

if [ "$fail" -eq 0 ]; then echo "Flutter import boundaries OK"; fi
exit "$fail"
