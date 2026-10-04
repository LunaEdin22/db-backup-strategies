#!/usr/bin/env bash
set -euo pipefail

# Uso: bash scripts/restore_test.sh backup_XXXX.dump.gpg
# Requiere: BACKUP_PASSPHRASE y PGHOST/PGUSER/PGPASSWORD de un Postgres temporal.

FILE="${1:?Indica el archivo .dump.gpg a restaurar}"

gpg --batch --yes --pinentry-mode loopback \
  --passphrase "$BACKUP_PASSPHRASE" -o restore.dump -d "$FILE"

createdb restore_check
pg_restore --no-owner -d restore_check restore.dump

COUNT=$(psql -d restore_check -tAc "SELECT count(*) FROM notes")
echo "Filas restauradas: $COUNT"

# Falla si la tabla está vacía (la restauración no sirvió de nada)
[ "$COUNT" -gt 0 ]

rm -f restore.dump
