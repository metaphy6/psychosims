#!/usr/bin/env bash
# Local logical-backup acceptance. Never connects to an existing database.
set -euo pipefail
cd "$(dirname "$0")/.."
pwd
image_ref='postgres@sha256:20edbde7749f822887a1a022ad526fde0a47d6b2be9a8364433605cf65099416'
docker image inspect "$image_ref" --format '{{.Id}}'
mkdir -p /tmp/agent-runs
drill_tmp="$(mktemp -d /tmp/agent-runs/restore-drill.XXXXXX)"
container_name="psychosims-restore-drill-$(date +%s)-$$"
container_started=false
cleanup() {
  if [[ "$container_started" == true ]]; then docker rm --force "$container_name"; fi
  rm -rf "$drill_tmp"
}
trap cleanup EXIT
docker run --pull=never --detach --rm --name "$container_name" \
  --tmpfs /var/lib/postgresql/data --publish 127.0.0.1::5432 \
  --env POSTGRES_HOST_AUTH_METHOD=trust --env POSTGRES_DB=psychosims_source "$image_ref"
container_started=true
ready=false
for ((attempt=0;attempt<30;attempt++)); do
  if docker exec "$container_name" pg_isready -h 127.0.0.1 -U postgres -d psychosims_source; then ready=true; break; fi
  sleep 1
done
if [[ "$ready" != true ]]; then docker logs "$container_name"; exit 1; fi
docker exec "$container_name" createdb -U postgres psychosims_restore
binding="$(docker port "$container_name" 5432/tcp)"
port="${binding##*:}"
export PSY_TEST_DATABASE_DSN="postgres://postgres@127.0.0.1:${port}/psychosims_source?sslmode=disable"
export PSY_RESTORE_DATABASE_DSN="postgres://postgres@127.0.0.1:${port}/psychosims_restore?sslmode=disable"
export PSY_RESTORE_CONTAINER="$container_name"
export TMPDIR="$drill_tmp"
cd server
pwd
go test -race -tags=postgres,restore -count=1 -run '^TestPostgresLogicalBackupRestore' -v ./internal/integration
