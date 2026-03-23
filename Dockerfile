FROM alpine:3.21

LABEL org.opencontainers.image.source="https://github.com/cameronsjo/immich-backup"
LABEL org.opencontainers.image.description="Encrypted Immich backup sidecar — pg_dump + photos to Azure via restic"
LABEL org.opencontainers.image.licenses="MIT"

RUN apk add --no-cache \
    restic \
    postgresql16-client \
    curl \
    jq \
    busybox-extras

COPY scripts/ /scripts/
RUN chmod +x /scripts/*.sh

RUN mkdir -p /data && chown nobody:nobody /data
VOLUME ["/data"]

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --retries=3 --start-period=120s \
    CMD wget -q --spider http://127.0.0.1:8080/cgi-bin/health || exit 1

ENTRYPOINT ["/scripts/entrypoint.sh"]
