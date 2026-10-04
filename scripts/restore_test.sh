#!/usr/bin/env bash
set -euo pipefail

# Requiere PGHOST, PGUSER y PGPASSWORD apuntando a un Postgres temporal.

S3_ARGS=()
if [ -n "${S3_ENDPOINT:-}" ]; then
  S3_ARGS=(--endpoint-url "$S3_ENDPOINT")
fi

LATEST=$(aws s3 ls "s3://${BACKUP_BUCKET}/daily/" "${S3_ARGS[@]}" \
  | sort | tail -1 | awk '{print $4}')

if [ -z "$LATEST" ]; then
  echo "ERROR: no hay backups en el bucket" >&2
  exit 1
fi
echo "Probando restauración de: $LATEST"

aws s3 cp "s3://${BACKUP_BUCKET}/daily/${LATEST}" . "${S3_ARGS[@]}"

gpg --batch --yes --pinentry-mode loopback \
  --passphrase "$BACKUP_PASSPHRASE" -o restore.dump -d "$LATEST"

createdb restore_check
pg_restore --no-owner -d restore_check restore.dump

COUNT=$(psql -d restore_check -tAc "SELECT count(*) FROM notes")
echo "Filas restauradas: $COUNT"

# Falla si la tabla está vacía (la restauración no sirvió de nada)
[ "$COUNT" -gt 0 ]

rm -f restore.dump "$LATEST"
