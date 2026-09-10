#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "▶️  Testing durable data boundaries with planted dialogue sentinels"
# Exercise production serializers/storage and inspect persisted data. A search
# for the word 'transcript' cannot establish this property and can match comments.
(cd app && pwd && flutter test --concurrency=1 \
  test/session_persistence_test.dart \
  test/career_persistence_test.dart \
  test/signed_receipt_queue_test.dart \
  test/durable_queue_persistence_test.dart)
# Includes the real PostgreSQL raw_transcript stripping/dead-letter regressions.
# Uses only an explicitly disposable DSN or its own short-lived local container.
bash server/scripts/postgres_test.sh
echo "✅ Durable data boundary tests passed"
