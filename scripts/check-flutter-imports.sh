#!/usr/bin/env bash
# Enforces Phase 2 import boundaries in the Flutter app:
#   1. firebase_auth may only be imported under lib/features/auth/.
#   2. the authenticated-user path (features/auth, core/network) must not
#      import supabase_flutter.
# The "Dio construction only in core/network" rule from the design (spec §8) is
# deliberately NOT enforced yet: evidence/profile still build Dio for R2 uploads
# until their own migration phase. Add that check when those features move.
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
  "$lib/features/auth" "$lib/core/network" || true)
if [ -n "$bad_sb" ]; then
  echo "ERROR: supabase_flutter imported on the auth path (features/auth, core/network):"
  echo "$bad_sb"
  fail=1
fi

if [ "$fail" -eq 0 ]; then echo "Flutter import boundaries OK"; fi
exit "$fail"
