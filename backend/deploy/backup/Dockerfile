# PepperCheck backup image: postgres:17 + the SAME pinned pgBackRest client
# as deploy/postgres (client and server-side pgBackRest must speak the same
# repository format; Task 3 of
# docs/superpowers/plans/2026-07-25-phase7a-infra-ops-foundation.md diffs the
# two `pgbackrest version` outputs), plus age + rclone for an independent
# daily logical (pg_dump) fallback -- all driven by a root cron daemon
# running the postgres user's crontab (see entrypoint.sh, crontab).
#
# pgBackRest is built from source at a pinned released git tag rather than
# apt-installed, for the identical reason as deploy/postgres/Dockerfile:
# apt.postgresql.org only offered 2.58.0 at build time, which lacks the
# archive-push-batch-size option (added in 2.59.0) pgbackrest.conf relies on.
# This builder stage is a byte-for-byte copy of deploy/postgres/Dockerfile's
# -- kept in lockstep by hand, since the two images are independent build
# contexts with no shared base to factor it into.
ARG PGBACKREST_VERSION=2.59.0

# ---- builder stage: compile pgBackRest from the release distribution tarball ----
# Same postgres:17 base as the final stage, so the resulting binary links the
# exact shared-library sonames already present at runtime (all of libssl3t64,
# libxml2, liblz4-1, libzstd1, libbz2-1.0, zlib1g, libpq5 ship in postgres:17).
FROM postgres:17 AS builder
ARG PGBACKREST_VERSION
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates curl meson ninja-build gcc pkg-config \
        libssl-dev libxml2-dev liblz4-dev libzstd-dev libbz2-dev zlib1g-dev libpq-dev \
    && rm -rf /var/lib/apt/lists/*
RUN mkdir -p /build \
    && curl -fsSL "https://github.com/pgbackrest/pgbackrest/releases/download/release%2F${PGBACKREST_VERSION}/pgbackrest-${PGBACKREST_VERSION}.tar.gz" \
        | tar zx -C /build \
    && meson setup /build/pgbackrest "/build/pgbackrest-${PGBACKREST_VERSION}" \
    && ninja -C /build/pgbackrest \
    && install -m 0755 /build/pgbackrest/src/pgbackrest /usr/bin/pgbackrest

# ---- final stage ----
FROM postgres:17
# The built binary's runtime shared libraries (libssl3t64, libxml2, liblz4-1,
# libzstd1, libbz2-1.0, zlib1g, libpq5) all already ship in postgres:17, so no
# extra runtime packages are needed for pgbackrest itself here.
COPY --from=builder /usr/bin/pgbackrest /usr/bin/pgbackrest

# age: encrypts the logical pg_dump fallback. cron: drives the schedule
# (crontab, below), started via `cron -f` in entrypoint.sh. rclone: uploads
# the age-encrypted dump to B2 (pgBackRest uploads its own full/diff/WAL
# backups directly, via the S3 repo driver configured in pgbackrest.conf --
# rclone is only for the separate age-dump path in backup.sh). NOTE: rclone
# is used instead of the MinIO "mc" client because "mc" is already a Debian
# package name (GNU Midnight Commander, an unrelated terminal file manager)
# -- installing it via apt would not get the MinIO client. pg_dump/pg_restore
# already ship in postgres:17.
RUN apt-get update \
    && apt-get install -y --no-install-recommends age cron rclone \
    && rm -rf /var/lib/apt/lists/*

COPY pgbackrest.conf /etc/pgbackrest/pgbackrest.conf
COPY backup.sh /usr/local/bin/backup.sh
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY crontab /var/spool/cron/crontabs/postgres

# COPY does not reliably propagate the executable bit across build contexts
# (see deploy/postgres/Dockerfile), so set it explicitly. cron refuses to
# load a crontab that is not exactly 0600 and owned by the user it names.
RUN chmod +x /usr/local/bin/backup.sh /usr/local/bin/entrypoint.sh \
    && mkdir -p /var/spool/cron/crontabs \
    && chown postgres:postgres /var/spool/cron/crontabs/postgres \
    && chmod 0600 /var/spool/cron/crontabs/postgres \
    && mkdir -p /var/spool/pgbackrest /var/log/pgbackrest \
    && chown -R postgres:postgres /var/spool/pgbackrest /var/log/pgbackrest

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
# Stays root (unlike deploy/postgres, which drops to postgres via the stock
# docker-entrypoint.sh): `cron -f` must start as root so it can fork each
# crontab job as the postgres user it is filed under.
