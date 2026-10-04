#!/usr/bin/env bash
set -euo pipefail

STAMP=$(date -u +%Y%m%dT%H%M%SZ)
FILE="backup_${STAMP}.dump"

# Argumentos opcionales para S3 compatible (R2, B2). Vacío si se usa AWS S3.
S3_ARGS=()
if [ -n "${S3_ENDPOINT:-}" ]; then
  S3_ARGS=(--endpoint-url "$S3_ENDPOINT")
fi

# Backup lógico en formato custom (comprimido y restaurable por partes)
pg_dump "$DATABASE_URL" --format=custom --no-owner --file="$FILE"

# Cifrado simétrico con GPG (la clave vive como secret)
gpg --batch --yes --pinentry-mode loopback \
  --passphrase "$BACKUP_PASSPHRASE" -c "$FILE"

# Subida a almacenamiento S3 compatible (AWS S3, Cloudflare R2, Backblaze B2)
aws s3 cp "${FILE}.gpg" "s3://${BACKUP_BUCKET}/daily/${FILE}.gpg" "${S3_ARGS[@]}"

rm -f "$FILE" "${FILE}.gpg"
echo "Backup OK: ${FILE}.gpg"
