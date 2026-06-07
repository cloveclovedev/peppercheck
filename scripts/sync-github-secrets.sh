#!/usr/bin/env bash
# Sync ~/.config/peppercheck/github-secrets with scripts/github-secrets.example.
#
# Preserves the value of every key still present in the template, drops keys
# the template no longer defines (saved to a timestamped .bak first), and
# leaves newly-added keys empty for the operator to fill in. The template
# is the source of truth for which keys belong; this script never echoes
# secret values to stdout / stderr.
#
# Usage: scripts/sync-github-secrets.sh
#
# Pre-req: ~/.config/peppercheck/github-secrets exists. If you have a legacy
# scripts/github-secrets file from before the Phase 1 relocation, move it
# manually:
#   mkdir -p ~/.config/peppercheck && chmod 700 ~/.config/peppercheck
#   mv scripts/github-secrets ~/.config/peppercheck/github-secrets
#   chmod 600 ~/.config/peppercheck/github-secrets
#
# Output:
#   ~/.config/peppercheck/github-secrets             (rewritten, mode 0600)
#   ~/.config/peppercheck/github-secrets.bak.<ISO>   (timestamped backup,
#                                                     keeps the 3 most
#                                                     recent generations;
#                                                     older ones are pruned)

set -euo pipefail
umask 077

repo_root="$(git rev-parse --show-toplevel)"
template="${repo_root}/scripts/github-secrets.example"
secrets_dir="${HOME}/.config/peppercheck"
current="${secrets_dir}/github-secrets"

if [[ ! -f "$template" ]]; then
  echo "ERROR: template not found at ${template}" >&2
  exit 1
fi
if [[ ! -f "$current" ]]; then
  echo "ERROR: current secrets file not found at ${current}" >&2
  echo "       If you have a legacy scripts/github-secrets, move it first:" >&2
  echo "         mkdir -p ${secrets_dir} && chmod 700 ${secrets_dir}" >&2
  echo "         mv ${repo_root}/scripts/github-secrets ${current}" >&2
  echo "         chmod 600 ${current}" >&2
  exit 1
fi

mkdir -p "$secrets_dir"
chmod 700 "$secrets_dir"

output_tmp="$(mktemp "${secrets_dir}/.github-secrets.sync.XXXXXX")"
report_tmp="$(mktemp "${secrets_dir}/.github-secrets.sync-report.XXXXXX")"
chmod 600 "$output_tmp" "$report_tmp"
trap 'rm -f "$output_tmp" "$report_tmp"' EXIT

# All key/value handling happens inside awk so the values never become bash
# variables in the controller process. The awk script writes the merged
# file content to stdout and writes "ORPHAN <key>" / "NEW <key>" lines —
# names only, never values — to stderr.
awk -v current="$current" -v template="$template" '
BEGIN {
    while ((getline line < current) > 0) {
        if (line ~ /^[[:space:]]*#/) continue
        if (line ~ /^[[:space:]]*$/) continue
        eq = index(line, "=")
        if (eq == 0) continue
        key = substr(line, 1, eq - 1)
        val = substr(line, eq + 1)
        cur_value[key] = val
        cur_seen[key] = 1
        cur_order[++ncur] = key
    }
    close(current)

    while ((getline line < template) > 0) {
        if (line ~ /^[[:space:]]*#/ || line ~ /^[[:space:]]*$/) {
            print line
            continue
        }
        eq = index(line, "=")
        if (eq == 0) {
            print line
            continue
        }
        key = substr(line, 1, eq - 1)
        tpl_seen[key] = 1
        if (key in cur_seen) {
            print key "=" cur_value[key]
        } else {
            print key "="
            new_order[++nnew] = key
        }
    }
    close(template)

    for (i = 1; i <= ncur; i++) {
        k = cur_order[i]
        if (!(k in tpl_seen)) {
            print "ORPHAN " k > "/dev/stderr"
        }
    }
    for (i = 1; i <= nnew; i++) {
        print "NEW " new_order[i] > "/dev/stderr"
    }
}
' > "$output_tmp" 2> "$report_tmp"

orphans=()
new_keys=()
while IFS=' ' read -r tag key || [[ -n "${tag:-}" ]]; do
  [[ -z "${tag:-}" ]] && continue
  case "$tag" in
    ORPHAN) orphans+=("$key") ;;
    NEW)    new_keys+=("$key") ;;
  esac
done < "$report_tmp"

timestamp="$(date -u +'%Y-%m-%dT%H-%M-%SZ')"
backup="${secrets_dir}/github-secrets.bak.${timestamp}"
cp "$current" "$backup"
chmod 600 "$backup"

# Keep the 3 most recent .bak files (including the one we just wrote);
# prune anything older. `ls -1 -t` sorts by modification time, newest first.
sorted_backups=()
while IFS= read -r f; do
  sorted_backups+=("$f")
done < <(ls -1 -t "${secrets_dir}"/github-secrets.bak.* 2>/dev/null || true)
if [[ ${#sorted_backups[@]} -gt 3 ]]; then
  i=3
  while [[ $i -lt ${#sorted_backups[@]} ]]; do
    rm -f "${sorted_backups[$i]}"
    echo "[prune] $(basename "${sorted_backups[$i]}")"
    i=$((i + 1))
  done
fi

mv "$output_tmp" "$current"
# Drop output_tmp from the trap now that it has been consumed.
trap 'rm -f "$report_tmp"' EXIT

echo "[ok] ${current} synced from $(basename "$template")"
echo "     backup: $(basename "$backup")"

if [[ ${#orphans[@]} -gt 0 ]]; then
  echo ""
  echo "Orphan keys (no longer defined by the template — removed from new file,"
  echo "preserved in backup for recovery if a key was renamed):"
  printf '  %s\n' "${orphans[@]}" | sort
fi

if [[ ${#new_keys[@]} -gt 0 ]]; then
  echo ""
  echo "New keys (defined by the template, empty in your new file — please fill"
  echo "in by editing ${current} directly, then run scripts/setup-github-secrets.sh):"
  printf '  %s\n' "${new_keys[@]}" | sort
fi
