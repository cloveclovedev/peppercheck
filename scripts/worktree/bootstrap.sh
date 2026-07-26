#!/usr/bin/env bash
# Bootstrap a Git worktree with the local configuration required to build and
# run PepperCheck. Only the reviewed paths below are copied; build artifacts,
# caches, and arbitrary ignored files are intentionally excluded.
#
# Run from the target worktree:
#   scripts/worktree/bootstrap.sh
#   scripts/worktree/bootstrap.sh --source /path/to/canonical/worktree
#   scripts/worktree/bootstrap.sh --skip-pub-get
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/worktree/bootstrap.sh
  scripts/worktree/bootstrap.sh --source /path/to/canonical/worktree
  scripts/worktree/bootstrap.sh --skip-pub-get
EOF
}

repo_root="$(git rev-parse --show-toplevel)"
source_root=""
run_pub_get=1

while [ "$#" -gt 0 ]; do
  case "$1" in
    --source)
      source_root="${2:?--source requires a path}"
      shift
      ;;
    --skip-pub-get)
      run_pub_get=0
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if [ -z "$source_root" ]; then
  source_root="$(git worktree list --porcelain | awk '/^worktree / { print substr($0, 10); exit }')"
fi

source_root="$(git -C "$source_root" rev-parse --show-toplevel)"
if [ "$source_root" = "$repo_root" ]; then
  echo "source and target worktrees must differ; pass --source explicitly if needed" >&2
  exit 2
fi

# Keep this list intentionally explicit. These are source-controlled path names
# but their contents are machine-local provider or signing configuration.
local_files=(
  backend/.env
  peppercheck_flutter/assets/env/.env.dev
  peppercheck_flutter/assets/env/.env.staging
  peppercheck_flutter/assets/env/.env.production
  peppercheck_flutter/android/app/src/dev/google-services.json
  peppercheck_flutter/android/app/src/staging/google-services.json
  peppercheck_flutter/android/app/src/production/google-services.json
  peppercheck_flutter/ios/Runner/Firebase/GoogleService-Info-Dev.plist
  peppercheck_flutter/ios/Runner/Firebase/GoogleService-Info-Staging.plist
  peppercheck_flutter/ios/Runner/Firebase/GoogleService-Info-Production.plist
  peppercheck_flutter/ios/Flutter/Secrets/Dev.secrets.xcconfig
  peppercheck_flutter/ios/Flutter/Secrets/Staging.secrets.xcconfig
  peppercheck_flutter/ios/Flutter/Secrets/Production.secrets.xcconfig
)

missing=0
for relative_path in "${local_files[@]}"; do
  if [ ! -f "$source_root/$relative_path" ]; then
    echo "missing required local configuration in source worktree: $relative_path" >&2
    missing=1
  fi
  if ! git -C "$repo_root" check-ignore -q -- "$relative_path"; then
    echo "refusing to copy to a path that is not ignored: $relative_path" >&2
    missing=1
  fi
done
[ "$missing" -eq 0 ] || exit 1

umask 077
for relative_path in "${local_files[@]}"; do
  mkdir -p "$(dirname "$repo_root/$relative_path")"
  cp -p "$source_root/$relative_path" "$repo_root/$relative_path"
  chmod 600 "$repo_root/$relative_path"
  echo "copied $relative_path"
done

if [ "$run_pub_get" -eq 1 ]; then
  (
    cd "$repo_root/peppercheck_flutter"
    flutter pub get
  )
fi

echo "worktree bootstrap complete"
