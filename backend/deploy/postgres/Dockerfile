# PepperCheck postgres image: postgres:17 + the pgBackRest client, so
# archive_command can push WAL straight from the server process, plus a root
# entrypoint that exports PGBACKREST_* from Docker file-based secrets before
# handing off to the stock entrypoint (Compose has no secret->env mechanism
# of its own -- see entrypoint.sh).
FROM postgres:17

# Pinned to the pgBackRest version available in postgres:17's
# apt.postgresql.org repo at build time (checked via `apt-cache policy
# pgbackrest` against this base image: candidate 2.58.0-1.pgdg13+1). The
# peppercheck-backup image (deploy/backup) MUST pin this identical version --
# client and server-side pgBackRest must speak the same repository format.
ARG PGBACKREST_VERSION=2.58.0
RUN apt-get update \
    && apt-get install -y --no-install-recommends "pgbackrest=${PGBACKREST_VERSION}*" \
    && rm -rf /var/lib/apt/lists/*

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
