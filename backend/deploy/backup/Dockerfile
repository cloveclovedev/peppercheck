# Postgres client tools (pg_dump matching server major 17) + age for client-side
# encryption. Alpine keeps the image small.
FROM postgres:17-alpine
RUN apk add --no-cache age
COPY backup.sh /usr/local/bin/backup.sh
RUN chmod +x /usr/local/bin/backup.sh
ENTRYPOINT ["/usr/local/bin/backup.sh"]
