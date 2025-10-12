#!/usr/bin/env bash
set -euo pipefail

# リポジトリを環境変数で指定（例：cloveclovedev/peppercheck）
REPO="${REPO:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"

echo "Using repo: $REPO"

# ----- type -----
gh label create 'type/bug'      --repo "$REPO" --color FFC0CB -d 'Bug'            || true
gh label create 'type/feature'  --repo "$REPO" --color 84b6eb -d 'Feature'        || true
gh label create 'type/task'     --repo "$REPO" --color c5def5 -d 'Task/Chore'     || true
gh label create 'type/docs'     --repo "$REPO" --color d4c5f9 -d 'Documentation'  || true
gh label create 'type/question' --repo "$REPO" --color c2e0c6 -d 'Question'       || true
gh label create 'type/spike'    --repo "$REPO" --color fef2c0 -d 'Spike/Research' || true

# ----- area -----
gh label create 'area/android'    --repo "$REPO" --color 1f883d -d 'Android'    || true
gh label create 'area/supabase'   --repo "$REPO" --color 5319e7 -d 'Supabase'   || true
gh label create 'area/cloudflare' --repo "$REPO" --color 0e8a16 -d 'Cloudflare' || true
gh label create 'area/web'        --repo "$REPO" --color 0052cc -d 'Web/LP'     || true
gh label create 'area/backend'    --repo "$REPO" --color 0366d6 -d 'Backend'    || true
gh label create 'area/infra'      --repo "$REPO" --color 6f42c1 -d 'Infra'      || true
gh label create 'area/design'     --repo "$REPO" --color ab77ff -d 'Design'     || true
gh label create 'area/ux'         --repo "$REPO" --color 9ad2ae -d 'UX'         || true


# ----- priority (P0 highest) -----
gh label create 'priority/P0' --repo "$REPO" --color b60205 -d 'Critical' || true
gh label create 'priority/P1' --repo "$REPO" --color d93f0b -d 'High'     || true
gh label create 'priority/P2' --repo "$REPO" --color fbca04 -d 'Medium'   || true
gh label create 'priority/P3' --repo "$REPO" --color 0e8a16 -d 'Low'      || true

# ----- optional, minimal status -----
gh label create 'status/triage' --repo "$REPO" --color 5319e7 -d 'Needs triage' || true

echo "Done."

