#!/usr/bin/env bash

set -euo pipefail

inventory_root="$(git rev-parse --show-toplevel)"
cd "$inventory_root"

count_lines() {
  awk 'END { print NR + 0 }'
}

extract_dart_calls() {
  local method="$1"

  git ls-files 'peppercheck_flutter/lib/**/*.dart' |
    while IFS= read -r source_file; do
      METHOD="$method" perl -0777 -ne '
        my $method = $ENV{"METHOD"};
        while (/\.$method(?:<[^>]+>)?\s*\(\s*["\x27]([^"\x27]+)["\x27]/g) {
          print "$1\n";
        }
      ' "$source_file"
    done
}

printf '%s\n' 'PepperCheck Go API/VPS Phase 0 inventory'
printf 'flutter_supabase_import_files=%s\n' "$(
  git grep -l 'package:supabase_flutter/supabase_flutter.dart' \
    -- 'peppercheck_flutter/lib/**/*.dart' | count_lines
)"
printf 'flutter_raw_dot_from_matches=%s\n' "$(
  git grep -o -E '\.from\(' -- 'peppercheck_flutter/lib/**/*.dart' | count_lines
)"
printf 'flutter_postgrest_table_calls=%s\n' "$(
  git grep -o -E "\.from\('[a-z_]+'\)" \
    -- 'peppercheck_flutter/lib/**/*.dart' | count_lines
)"
printf 'flutter_rpc_calls=%s\n' "$(
  git grep -o -E '\.rpc(<[^>]+>)?\(' \
    -- 'peppercheck_flutter/lib/**/*.dart' | count_lines
)"
printf 'flutter_distinct_rpc_functions=%s\n' "$(
  extract_dart_calls rpc | sort -u | count_lines
)"
printf 'flutter_edge_function_calls=%s\n' "$(
  git grep -o -E '\.functions\.invoke\(' \
    -- 'peppercheck_flutter/lib/**/*.dart' | count_lines
)"
printf 'flutter_distinct_edge_functions=%s\n' "$(
  extract_dart_calls 'functions\.invoke' | sort -u | count_lines
)"
printf 'schema_functions=%s\n' "$(
  git grep -i -E '^CREATE( OR REPLACE)? FUNCTION' \
    -- 'supabase/schemas/**/*.sql' | count_lines
)"
printf 'schema_triggers=%s\n' "$(
  git grep -i -E '^CREATE( OR REPLACE)? TRIGGER' \
    -- 'supabase/schemas/**/*.sql' | count_lines
)"
printf 'schema_housekeeping_triggers=%s\n' "$(
  git grep -i -E 'EXECUTE FUNCTION public\.handle_updated_at\(\)' \
    -- 'supabase/schemas/**/triggers/*.sql' | count_lines
)"
printf 'schema_business_triggers=%s\n' "$(
  git grep -i -E '^CREATE( OR REPLACE)? TRIGGER' \
    -- 'supabase/schemas/**/*.sql' |
    grep -v 'updated_at' |
    count_lines
)"
printf 'schema_cron_jobs=%s\n' "$(
  git grep -i -E 'cron\.schedule\(' \
    -- 'supabase/schemas/**/cron/*.sql' | count_lines
)"
printf 'edge_function_directories=%s\n' "$(
  git ls-files 'supabase/functions/*/index.ts' | count_lines
)"

printf '\n%s\n' 'Flutter RPC functions:'
extract_dart_calls rpc | sort -u

printf '\n%s\n' 'Flutter Edge Function targets:'
extract_dart_calls 'functions\.invoke' | sort -u

printf '\n%s\n' 'Deployed Edge Function source directories:'
git ls-files 'supabase/functions/*/index.ts' |
  awk -F/ '{ print $3 }' |
  sort -u
