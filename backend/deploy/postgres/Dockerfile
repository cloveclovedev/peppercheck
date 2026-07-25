# PepperCheck postgres image: postgres:17 + the pgBackRest client, so
# archive_command can push WAL straight from the server process, plus a root
# entrypoint that exports PGBACKREST_* from Docker file-based secrets before
# handing off to the stock entrypoint (Compose has no secret->env mechanism
# of its own -- see entrypoint.sh).

# pgBackRest is built from source at a pinned released git tag rather than
# apt-installed: apt.postgresql.org only offered 2.58.0 at build time, which
# lacks the archive-push-batch-size option (added in 2.59.0) that the archive
# async config below relies on. The peppercheck-backup image (deploy/backup)
# MUST build pgBackRest from source the same way at this IDENTICAL
# PGBACKREST_VERSION -- client and server-side pgBackRest must speak the same
# repository format, and Task 3 diffs the two `pgbackrest version` outputs.
#
# 2.59.0 = newest stable release at build time and PG17-compatible. Build
# procedure follows the official pgBackRest user guide "Build" section
# (meson + ninja; https://pgbackrest.org/user-guide.html) and the dependency
# set declared in the project's meson.build (openssl>=1.1.1, libxml-2.0,
# liblz4, libzstd, bz2, zlib, libpq -- yaml is only needed for the code-gen
# tooling, which a distribution tarball skips via its baked-in `dist` marker).
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
# extra runtime packages are installed here -- only the binary is copied in.
COPY --from=builder /usr/bin/pgbackrest /usr/bin/pgbackrest

COPY pgbackrest.conf /etc/pgbackrest/pgbackrest.conf
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY init/* /docker-entrypoint-initdb.d/

# COPY does not reliably propagate the executable bit across build contexts,
# and docker-entrypoint.sh only sources (rather than execs) non-executable
# *.sh files in /docker-entrypoint-initdb.d/, so set it explicitly.
RUN chmod +x /usr/local/bin/entrypoint.sh /docker-entrypoint-initdb.d/*.sh \
    && mkdir -p /var/spool/pgbackrest /var/log/pgbackrest \
    && chown -R postgres:postgres /var/spool/pgbackrest /var/log/pgbackrest

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
# Empty by design. The base image sets CMD ["postgres"]; left as-is, that
# arg would be appended to entrypoint.sh's own hardcoded "postgres" arg
# (see entrypoint.sh), producing `docker-entrypoint.sh postgres postgres`,
# which the postgres binary rejects with `invalid argument: "postgres"`.
CMD []
