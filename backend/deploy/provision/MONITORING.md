# PepperCheck Monitoring

Operator reference for Phase 7-A monitoring & alerting (design doc
`docs/designs/2026-07-25-phase7a-infra-ops-foundation-design.md`
§9, Task 17). This document is the install/enable + runbook reference for
what Task 17 built; **Task 22 ("Wire staging monitoring")** is the separate
step that actually creates the real Better Stack monitors/heartbeats for a
live environment and points this machinery at them — this document assumes
that step (or its production equivalent) has been done, or explains what
each piece needs once it is.

## 1. What's monitored, and by what

| Signal | Mechanism | Cadence | Paging |
|---|---|---|---|
| `/livez`, `/readyz` uptime | Better Stack **uptime monitor** (HTTP check) | Better Stack's own | production pages; staging non-paging |
| TLS certificate expiry | Better Stack **TLS-expiry check** on the same uptime monitor | Better Stack's own | production pages; staging non-paging |
| Worker liveness | Better Stack **heartbeat**, pinged by the `worker` process after every successful `RunDue` cycle (`internal/worker/worker.go`, `HEARTBEAT_URL_WORKER`) | every worker tick (~1s local; see `Worker.interval`) | production pages on missed heartbeat; staging non-paging |
| Logical (age-encrypted) backup cycle | Better Stack **heartbeat**, pinged by `deploy/backup/backup.sh` after a successful dump+upload (`HEARTBEAT_URL_BACKUP`) | daily (crontab `0 3 * * *`) | production pages on missed heartbeat; staging non-paging |
| WAL-archiving freshness (multi-signal RPO) | Better Stack **heartbeat**, pinged by `deploy/monitor/wal-freshness.sh` only when every signal is healthy | every 2 minutes (systemd timer) | production pages on missed heartbeat; staging non-paging |
| Host inode usage + container restart counts | Better Stack **heartbeat**, pinged by `deploy/monitor/host-checks.sh` only when healthy | every 5 minutes (systemd timer) | production pages on missed heartbeat; staging non-paging |
| Host CPU / load / memory / filesystem bytes / bandwidth | **DigitalOcean Monitoring** (native, not this repo) | DO's own | configure DO alert policies per environment; staging non-paging |

**Design choice — heartbeat-only, not a payloaded status push.** Every
custom check in this repo (worker, backup, `wal-freshness.sh`,
`host-checks.sh`) follows the same pattern: ping a Better Stack heartbeat
URL **only when healthy**, and always emit a structured JSON line (`status`,
every raw value, `reasons` when unhealthy) to stdout, which systemd/journald
captures. Better Stack's own missed-heartbeat alerting is what actually
pages — on an unhealthy result (the script stops pinging), on the script
crashing, or on the timer/service disappearing entirely. This was a
deliberate simplification over inventing a bespoke payloaded-webhook
contract (e.g. Better Stack's Incidents API) that this task could not fully
exercise or verify end-to-end in this environment; if a future review
prefers push-on-failure with the actual values embedded (e.g. via the
Incidents API), that is a compatible enhancement — the JSON line already
has everything such a payload would need.

## 2. Better Stack setup (Task 22 performs this against real environments)

1. Create one **uptime monitor** per environment against
   `https://staging.peppercheck.dev/readyz` (or `/readyz` on production),
   with TLS-expiry checking enabled. Also add a **secondary check** on
   `/livez` if independent liveness (vs. dependency-readiness) visibility is
   wanted.
2. Create **four heartbeats per environment**: worker, backup, wal-freshness,
   host-checks. Each Better Stack heartbeat gives you a unique URL of the
   form `https://uptime.betterstack.com/api/v1/heartbeat/<token>` — the
   token is a secret (treat it like any other credential; do not commit it).
   Set each heartbeat's expected period + grace generously above its actual
   cadence (e.g. worker: a few minutes; backup: ~36h; wal-freshness: ~6
   minutes; host-checks: ~15 minutes) so ordinary jitter never pages, but a
   genuinely stopped process does within an acceptable window.
3. **Staging must be non-paging.** Configure staging's monitors/heartbeats
   to notify a dashboard-only channel (or an email alias nobody's on-call
   watches), never the paging integration. Only production's monitors are
   wired to the paging channel.
4. Document a maintenance-window procedure before intentionally stopping
   staging (e.g. to save cost, or during a restore drill): use Better
   Stack's maintenance-window feature on staging's monitors/heartbeats for
   the stop window, so an intentional stop never fires an alert (even a
   non-paging one) that could mask a real, separate problem.

## 3. DigitalOcean host alerts

Configure DO Monitoring alert policies (per Droplet, per environment) for
CPU, load average, memory, filesystem bytes, and bandwidth, using DO's
built-in graphs/policies — no code in this repo is involved. **Inode usage
and container restart counts are explicitly NOT DO Monitoring metrics**
(design doc §9); that gap is exactly what `host-checks.sh` fills.

## 4. Delivering Better Stack URLs: BWS → env file the units read

The four heartbeat URLs (worker, backup, wal-freshness, host-checks) are
secrets (each embeds an auth token) and must never be committed or placed in
`compose.prod.yaml` as a literal. They travel the same way every other
Phase 7-A secret does — **Bitwarden Secrets Manager (BWS) is the system of
record** — but `wal-freshness.sh`/`host-checks.sh` run as **host-level
systemd units, not containers**, so they cannot use the `*_FILE` /
Docker-secret convention `internal/core/config` and the containers use.
Instead:

1. Add four secrets to each environment's BWS project (staging,
   production), alongside the existing ten (§1.2 of `RUNBOOK.md`):
   `heartbeat_url_worker`, `heartbeat_url_backup`,
   `heartbeat_url_wal_freshness`, `heartbeat_url_host_checks`.
2. On the Droplet, render them (e.g. via `bws run` in an operator session,
   or a small extension of the deploy pipeline in a later task) into
   `/etc/peppercheck/monitor.env`, owned `root:root`, mode `0600`:

   ```bash
   install -d -m 0755 /etc/peppercheck
   umask 077
   cat > /etc/peppercheck/monitor.env <<EOF
   PC_ENV=staging
   WAL_FRESHNESS_HEARTBEAT_URL=$(bws secret get <id-for-heartbeat_url_wal_freshness> --output json | jq -r .value)
   HOST_CHECKS_HEARTBEAT_URL=$(bws secret get <id-for-heartbeat_url_host_checks> --output json | jq -r .value)
   EOF
   chmod 0600 /etc/peppercheck/monitor.env
   ```

   `worker`'s and `backup`'s heartbeat URLs are **container** env vars
   (`HEARTBEAT_URL_WORKER` on the `worker` service, `HEARTBEAT_URL_BACKUP`
   on the `backup` service) — they do NOT belong in
   `/etc/peppercheck/monitor.env`. Wiring them through
   `compose.prod.yaml`/`ship-deployment.sh` (the same non-secret-vars-vs-
   Docker-secrets question every other compose env var already answers) is
   Task 22's job, not repeated here; until that wiring lands, `Config.Load()`
   simply resolves `HEARTBEAT_URL_WORKER`/`HEARTBEAT_URL_BACKUP` to empty and
   both heartbeats stay silently disabled (by design — optional, fail-open,
   never fatal).
3. `wal-freshness.service`/`host-checks.service` read
   `/etc/peppercheck/monitor.env` via `EnvironmentFile=` (systemd's native
   mechanism for exactly this: a root-only file of `KEY=value` lines, no
   secret ever appears in a unit file, a process listing, or the journal
   unless the script itself misbehaves and logs it — which is why every
   script here is careful to never log its own heartbeat URL verbatim).

## 5. Install & enable the systemd units

Run on the Droplet, as root, once `/etc/peppercheck/monitor.env` exists
(§4):

```bash
apt-get install -y jq   # wal-freshness.sh needs it; not installed by bootstrap.sh today
install -d -m 0755 /var/lib/peppercheck-monitor   # STATE_DIR default; wal-freshness.sh also mkdir -p's this itself

install -m 0755 backend/deploy/monitor/wal-freshness.sh /opt/peppercheck/scripts/wal-freshness.sh
install -m 0755 backend/deploy/monitor/host-checks.sh   /opt/peppercheck/scripts/host-checks.sh

install -m 0644 backend/deploy/monitor/wal-freshness.service /etc/systemd/system/peppercheck-wal-freshness.service
install -m 0644 backend/deploy/monitor/wal-freshness.timer   /etc/systemd/system/peppercheck-wal-freshness.timer
install -m 0644 backend/deploy/monitor/host-checks.service   /etc/systemd/system/peppercheck-host-checks.service
install -m 0644 backend/deploy/monitor/host-checks.timer     /etc/systemd/system/peppercheck-host-checks.timer

systemctl daemon-reload
systemctl enable --now peppercheck-wal-freshness.timer
systemctl enable --now peppercheck-host-checks.timer
```

Note the rename at install time: the repo files are named
`wal-freshness.service`/`.timer` and `host-checks.service`/`.timer` (matching
their script basenames), but are installed under the `peppercheck-` prefix
so they cannot collide with an unrelated unit of the same bare name on a
shared host — the `.timer` files' `Unit=` line already points at the
prefixed `.service` name, so both must be renamed together.

Verify:

```bash
systemctl list-timers 'peppercheck-*'
journalctl -u peppercheck-wal-freshness.service -n 20
journalctl -u peppercheck-host-checks.service -n 20
```

A healthy run's journal line looks like `{"level":"info","status":"ok",...}`;
an unhealthy one is `{"level":"error","status":"alert",...,"reasons":"..."}`
and the systemd unit shows as failed until the next timer tick retries it.

Re-running the `install`/`systemctl enable --now` block is idempotent —
safe on every redeploy of these specific files (e.g. after a threshold
tuning change committed to the repo).

## 6. WAL-drop → new-full-backup PITR-rebuild runbook

**Background.** `pgbackrest.conf` sets `archive-push-queue-max=1GiB`
(design doc §8.2). If the async local queue ever exceeds that limit,
pgBackRest drops the oldest queued WAL segment(s) **and still returns
success to Postgres** — this is documented pgBackRest async archive-push
behavior, not a bug. Postgres then believes those segments are safely
archived and reclaims them from `pg_wal`. The PITR chain from that point
forward is **permanently broken**: no future successful archiving un-breaks
it, because the gap is a segment that no longer exists anywhere (not on the
Droplet, not in the repo). The only fix is a **new full backup**, which
establishes a fresh, gap-free starting point for PITR.

**Detection — and its honest limits (B2 continuity residual).**
`wal-freshness.sh` layers several signals. Understand precisely which one
catches this hazard **before** the drop versus only **after**, because the
"after" signals have a real blind spot:

- **PRIMARY, pre-drop:** the `.ready` backlog **byte** pre-alert
  (`WAL_BACKLOG_ALERT_RATIO`, default **0.5 = 512 MiB** of the 1 GiB
  `archive-push-queue-max`). This is the one signal that fires **while the
  queue is merely growing, before any WAL is dropped**, giving the operator
  a window to react (see "Address the root cause" below) before the chain
  can break. It is deliberately conservative for exactly that reason — do
  not raise the ratio without a concrete justification.
- **POST-drop backstop:** a match against pgBackRest's own queue-exceeded
  log line (best-effort regex `WAL_FRESHNESS_QUEUE_LOG_PATTERN`; **not
  independently confirmed against a live overflow in this environment** —
  see the hard Task-21 requirement below). Sticky on disk at
  `$STATE_DIR/wal-freshness.queue-exceeded` (default
  `/var/lib/peppercheck-monitor/wal-freshness.queue-exceeded`); does **not**
  self-clear — see step 4 below.
- the latest-backup age exceeding `MAX_BACKUP_AGE_SECONDS` (a full/diff that
  should have run didn't, for whatever reason, including this one).
- the B2-confirmed archive **max** (from `pgbackrest info`) persistently
  lagging behind `pg_stat_archiver.last_archived_wal` (`B2_LAG_ALERT_STREAK`,
  default 3 ≈ 6 minutes). **This is a max-lag signal, NOT a continuity
  signal**, and it has a documented blind spot for THIS hazard: a queue-max
  overflow drops the OLDEST queued segment and keeps pushing newer ones, so
  `b2_archive_max` keeps advancing in lockstep with `last_archived_wal` and
  this check stays quiet even though a **gap sits undetected in the middle**
  of the archived range. It reliably catches a *stalled/behind* transfer
  (B2 unreachable, credentials wrong), not a mid-stream drop.

**Why no per-segment gap scan.** The ideal signal would enumerate the repo
archive and detect a missing segment directly. `pgbackrest info
--output=json` exposes only the archive range's `min`/`max` per archive-id
— never a per-segment list or count — so a real gap scan would require
`pgbackrest repo-ls` over the repo's archive path plus WAL-name arithmetic
across the 256-segments-per-logfile boundary, correct handling of the repo
path layout and compression suffixes, and paging thousands of segments every
2 minutes. That is fragile to get correct in shell and could not be verified
against real pgBackRest output in the Task 17 sandbox, so it was
deliberately **not** implemented; the pre-drop pre-alert + sticky
log-pattern backstop are the accepted mitigation instead. If a future task
can enumerate the repo cleanly, adding a genuine continuity check is the
right upgrade.

> **HARD REQUIREMENT for Task 21 (WAL-drop drill).** Because the mid-stream-
> drop case rests on the sticky **log-pattern** backstop, and that pattern is
> currently **unverified against real pgBackRest output**, Task 21's WAL-drop
> drill MUST: (1) force a *real* `archive-push-queue-max` overflow against
> the test bucket (not a simulated log line), (2) capture pgBackRest's actual
> queue-exceeded log wording, and (3) confirm `wal-freshness.sh`'s
> `WAL_FRESHNESS_QUEUE_LOG_PATTERN` actually matches it and the sticky alert
> fires. If the real wording does not match, tighten the pattern to the
> observed string before staging monitoring is considered wired. Do not sign
> off Task 21 with this left unverified.

**Recovery steps**, once alerted:

1. Confirm the diagnosis: check `journalctl -u peppercheck-wal-freshness
   .service` for the specific `reasons` field, and independently run
   `docker exec <postgres-container> pgbackrest --stanza=main info` to see
   pgBackRest's own view of the archive/backup state. Also grep
   `/var/log/pgbackrest/*.log` (via `docker exec`) for the actual
   queue-related WARN line to confirm this is really a queue-max overflow
   and not, e.g., a network partition to B2 (which would self-heal without
   needing a new full backup).
2. Address the root cause first if it is ongoing (e.g. B2 connectivity, a
   sustained write-rate spike far beyond `archive-push-queue-max`) — taking
   a new full backup while the underlying problem is still active just
   repeats the failure.
3. Take a **new full backup** to re-establish the PITR chain:

   ```bash
   docker exec <postgres-container> sh -c '
     read_secret() { [ -f "$1" ] && tr -d "\n" < "$1"; }
     export PGBACKREST_REPO1_CIPHER_PASS="$(read_secret /run/secrets/pgbackrest_cipher)"
     export PGBACKREST_REPO1_S3_KEY="$(read_secret /run/secrets/b2_key_id)"
     export PGBACKREST_REPO1_S3_KEY_SECRET="$(read_secret /run/secrets/b2_key_secret)"
     pgbackrest --stanza=main --type=full backup
   '
   ```

   Everything before this full backup is no longer restorable to an
   arbitrary point in time (the WAL gap makes replay past the gap
   impossible) — it remains restorable only up to the last backup that
   predates the gap, which is exactly why a fresh full backup is the fix,
   not a diff/incremental (a diff/incremental still depends on the broken
   WAL chain back to its own parent full).
4. Once the new full backup completes successfully, clear the sticky
   detection state so `wal-freshness.sh` stops alerting on the
   already-resolved historical event:

   ```bash
   rm -f /var/lib/peppercheck-monitor/wal-freshness.queue-exceeded
   ```

   Do this only after step 3 actually succeeded — clearing it earlier would
   silence a real, still-broken PITR chain.
5. Record the incident (cause, detection time, recovery time) against the
   4-hour RTO target (design doc §8.4/§12) even though this specific
   scenario is a proactive rebuild, not a live restore — it is a leading
   indicator of restore-readiness risk.
6. Consider whether `archive-push-queue-max` needs raising (more B2-transfer
   headroom) or whether the write-rate event that caused the backlog is
   likely to recur, and adjust `WAL_BACKLOG_ALERT_RATIO`/the pre-alert
   threshold accordingly so the **next** approach to the limit pages before
   it overflows again.

## 7. Known gaps / follow-ups (see the Task 17 report for full detail)

- **B2 continuity residual (see §6).** There is no per-segment gap scan; the
  mid-stream-drop case rests on the `.ready` pre-drop pre-alert (primary) +
  the sticky queue-exceeded log-pattern backstop. Task 21's WAL-drop drill
  MUST verify that backstop against a *real* overflow (hard requirement,
  §6). A genuine `repo-ls`-based continuity check is the right future
  upgrade if the repo can be enumerated cleanly.
- The exact pgBackRest log wording for a queue-max-exceeded event has not
  been confirmed against a live overflow in this environment (no real B2
  bucket in this sandbox) — `WAL_FRESHNESS_QUEUE_LOG_PATTERN` is a
  deliberately broad best-effort regex. Confirm/tighten it during Task 21's
  **real** (not simulated) WAL-drop drill — this is the hard requirement in
  §6, not merely a nice-to-have.
- The `pgbackrest info --output=json` field names used (`archive[].max`,
  `backup[].timestamp.stop`) match pgBackRest's documented JSON schema but
  were only validated against a hand-built sample in this task, not a live
  pgBackRest 2.59.0 run against a real repo.
- `HEARTBEAT_URL_WORKER`/`HEARTBEAT_URL_BACKUP` are read by the Go config
  and by `backup.sh` respectively, but are not yet wired into
  `compose.prod.yaml`/`ship-deployment.sh`/`RUNBOOK.md`'s Environment-variable
  table — that wiring is Task 22's job (§4 above).
- `jq` is required on the Droplet host for `wal-freshness.sh` but is not
  installed by `bootstrap.sh` today — install it manually (§5) until
  `bootstrap.sh` is updated, or add it there in a follow-up.
