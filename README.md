# db-backup-strategies

API mínima en FastAPI + PostgreSQL con una estrategia de backups automatizada:
backup lógico diario, cifrado con GPG, almacenamiento externo S3 compatible y
prueba de restauración automática, todo con GitHub Actions. Desplegado en Railway.

## Ejecutar en local

```bash
docker compose up --build
curl -X POST "http://localhost:8000/notes?text=hola"
curl http://localhost:8000/notes
```

## Despliegue en Railway

1. Crea un proyecto y añade **PostgreSQL**.
2. Añade un servicio desde este repo con *Root Directory* = `app/`.
3. En el servicio de la app define `DATABASE_URL = ${{Postgres.DATABASE_URL}}`
   (URL privada).
4. En el servicio Postgres activa *Settings → Networking → TCP Proxy* (puerto 5432)
   y copia `DATABASE_PUBLIC_URL`.
5. Cada push a `main` redespliega la app automáticamente.

## Secrets de GitHub (Settings → Secrets and variables → Actions)

| Secret | Descripción |
|---|---|
| `DATABASE_URL` | URL **pública** (TCP proxy) de Postgres en Railway |
| `BACKUP_PASSPHRASE` | Contraseña para cifrar los backups con GPG |
| `BACKUP_BUCKET` | Nombre del bucket S3/R2/B2 |
| `S3_ENDPOINT` | Endpoint S3 compatible (vacío si usas AWS S3) |
| `AWS_ACCESS_KEY_ID` | Credencial del bucket |
| `AWS_SECRET_ACCESS_KEY` | Credencial del bucket |

## Backups

- Workflow: `.github/workflows/backup.yml`, diario a las 03:00 UTC.
- Manual: pestaña **Actions → Daily DB Backup → Run workflow**.
- `PG_VERSION` del workflow debe coincidir con la versión mayor de tu Postgres.
- Configura una *lifecycle policy* en el bucket para la retención
  (por ejemplo 7 diarios, 4 semanales, 6 mensuales).

## Restauración manual

```bash
aws s3 cp s3://BUCKET/daily/backup_XXXX.dump.gpg .
gpg -o restore.dump -d backup_XXXX.dump.gpg
pg_restore --no-owner -d "$DATABASE_URL_DESTINO" restore.dump
```

## Notas

- Los workflows programados en repos públicos se desactivan tras 60 días sin actividad.
- Activa notificaciones de GitHub para fallos de workflow (alertas si el job falla).
- Nunca subas backups ni secretos al repositorio.
