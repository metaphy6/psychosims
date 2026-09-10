#!/usr/bin/env bash
# Local real-PostgreSQL gate. A supplied DSN MUST point to a disposable database:
# the integration tests intentionally truncate their tables and exercise rollbacks.
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root/server"
pwd
test_args=(-race -tags=postgres -count=1 ./...)
if [[ "${1:-}" == "--flutter" ]]; then
  test_args=(-race -tags=postgres,flutter -count=1 -run '^TestPostgresDartControlPlane$' -v ./internal/integration)
elif [[ "${1:-}" == "--load" ]]; then
  test_args=(-race -tags=postgres,load -count=1 -run '^TestPostgresLocal' -v ./internal/integration)
elif [[ "${1:-}" == "--certified" ]]; then
  test_args=(-race -tags=postgres -count=1 -run '^TestPostgres(HTTPCertified|Certified|Certification)' -v ./internal/integration)
elif [[ $# -gt 0 ]]; then
  echo 'usage: postgres_test.sh [--flutter|--load|--certified]' >&2
  exit 2
fi
if [[ -n "${PSY_TEST_DATABASE_DSN:-}" ]]; then
  exec go test "${test_args[@]}"
fi
# Never silently download an image or touch pre-existing containers.
image_ref='postgres@sha256:20edbde7749f822887a1a022ad526fde0a47d6b2be9a8364433605cf65099416'
docker image inspect "$image_ref" --format '{{.Id}}'
container_name="psychosims-postgres-test-$(date +%s)-$$"
cleanup() { docker rm --force "$container_name"; }
trap cleanup EXIT
# Trust is confined to this short-lived, loopback-only test database.
docker run --pull=never --detach --rm --name "$container_name" \
  --tmpfs /var/lib/postgresql/data \
  --publish 127.0.0.1::5432 \
  --env POSTGRES_HOST_AUTH_METHOD=trust --env POSTGRES_DB=psychosims_test \
  "$image_ref"
ready=false
for ((attempt=0;attempt<30;attempt++)); do
  if docker exec "$container_name" pg_isready -h 127.0.0.1 -U postgres -d psychosims_test; then ready=true; break; fi
  sleep 1
done
if [[ "$ready" != true ]]; then docker logs "$container_name"; exit 1; fi
binding="$(docker port "$container_name" 5432/tcp)"
port="${binding##*:}"
export PSY_TEST_DATABASE_DSN="postgres://postgres@127.0.0.1:${port}/psychosims_test?sslmode=disable"
go test "${test_args[@]}"
