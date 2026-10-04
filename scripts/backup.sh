#!/usr/bin/env bash
set -euo pipefail

# Requiere: DATABASE_URL (URL pública de Railway) y BACKUP_PASSPHRASE.

STAMP=$(date -u +%Y%m%dT%H%M%SZ)
DUMP="backup_${STAMP}.dump"

# Backup lógico en formato custom (comprimido y restaurable por partes)
pg_dump "$DATABASE_URL" --format=custom --no-owner --file="$DUMP"

# Cifrado simétrico con GPG (genera ${DUMP}.gpg)
gpg --batch --yes --pinentry-mode loopback \
  --passphrase "$BACKUP_PASSPHRASE" -c "$DUMP"

# Borra el dump sin cifrar: solo queda el archivo .gpg
rm -f "$DUMP"

# Expone el sello de tiempo al workflow de GitHub Actions
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "stamp=${STAMP}" >> "$GITHUB_OUTPUT"
fi

echo "Backup OK: ${DUMP}.gpg"
