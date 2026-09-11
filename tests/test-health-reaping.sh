#!/usr/bin/env bash
set -euo pipefail

readonly IMAGE="${IMAGE:-immich-backup:test-health-reaping}"
readonly CONTAINER="immich-backup-health-reaping-$$"
readonly DATA_VOLUME="immich-backup-health-reaping-$$"

cleanup() {
    if docker container inspect "$CONTAINER" >/dev/null 2>&1; then
        docker rm -f "$CONTAINER" >/dev/null
    fi
    if docker volume inspect "$DATA_VOLUME" >/dev/null 2>&1; then
        docker volume rm "$DATA_VOLUME" >/dev/null
    fi
}
trap cleanup EXIT

docker volume create "$DATA_VOLUME" >/dev/null
docker run --rm --volume "$DATA_VOLUME:/data" alpine:3.21 \
    touch /data/last-backup
docker build -t "$IMAGE" .
docker run --detach --name "$CONTAINER" \
    --env AZURE_ACCOUNT_NAME=test-account \
    --env AZURE_ACCOUNT_KEY=test-key \
    --env RESTIC_REPOSITORY=/data/restic-repository \
    --env RESTIC_PASSWORD=test-password \
    --volume "$DATA_VOLUME:/data" \
    "$IMAGE" >/dev/null

ready=false
for _ in {1..30}; do
    if docker exec "$CONTAINER" wget -q -O /dev/null http://127.0.0.1:8080/cgi-bin/health; then
        ready=true
        break
    fi
    sleep 1
done
if [[ "$ready" != true ]]; then
    docker logs "$CONTAINER"
    echo "Health endpoint did not become ready" >&2
    exit 1
fi

for _ in {1..100}; do
    docker exec "$CONTAINER" wget -q -O /dev/null http://127.0.0.1:8080/cgi-bin/health
done

readonly LOG_PROBE="health-reaping-log-probe"
docker exec "$CONTAINER" sh -c 'printf "%s\n" "$1" >/proc/1/fd/1' sh "$LOG_PROBE"
container_logs="$(docker logs "$CONTAINER" 2>&1)"
if [[ "$container_logs" != *"$LOG_PROBE"* ]]; then
    echo "Expected /proc/1/fd/1 output to reach container logs" >&2
    exit 1
fi

pid_one="$(docker exec "$CONTAINER" cat /proc/1/comm)"
if [[ "$pid_one" != tini ]]; then
    echo "Expected tini as PID 1, got: $pid_one" >&2
    exit 1
fi

zombie_count=unknown
for _ in {1..50}; do
    zombie_count="$(docker exec "$CONTAINER" sh -c '
count=0
for stat in /proc/[0-9]*/stat; do
    state=$(awk "{print \$3}" "$stat")
    if [ "$state" = Z ]; then
        count=$((count + 1))
    fi
done
printf "%s\n" "$count"
')"
    if [[ ! "$zombie_count" =~ ^[0-9]+$ ]]; then
        echo "Expected a numeric zombie count, got: $zombie_count" >&2
        exit 1
    fi
    if ((zombie_count == 0)); then
        break
    fi
    sleep 0.1
done
if ((zombie_count != 0)); then
    echo "Expected no zombie processes after health probes, found: $zombie_count" >&2
    exit 1
fi

printf 'Health reaping test passed: PID 1=%s, zombies=%s\n' "$pid_one" "$zombie_count"
