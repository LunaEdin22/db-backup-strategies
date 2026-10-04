# db-backup-strategies

## Estudiante: Edinson Oscar Luna Peña

API mínima en FastAPI + PostgreSQL con backups automatizados: backup lógico
diario, cifrado con GPG, almacenamiento como artifact de GitHub Actions y prueba
de restauración automática. App y base de datos en Railway. Sin AWS ni S3.

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

## Backups

- Workflow: `.github/workflows/backup.yml`, diario a las 03:00 UTC.
- Manual: pestaña **Actions → Daily DB Backup → Run workflow**.
- El backup cifrado se guarda como artifact (retención de 30 días, máximo 90).
- El job `restore-test` descarga ese backup, lo restaura en un Postgres temporal
  y falla si la tabla `notes` queda vacía.
- `PG_VERSION` del workflow debe coincidir con la versión mayor de tu Postgres.

## Restauración manual

1. Descarga el artifact desde la pestaña Actions y descomprímelo.
2. Descífralo y restáuralo:

```bash
gpg -o restore.dump -d backup_XXXX.dump.gpg
pg_restore --no-owner -d "URL_DE_LA_BASE_DESTINO" restore.dump
```

## Limitaciones (demo)

- Los artifacts viven en GitHub: la copia está fuera de Railway, pero no cumple
  la regla 3-2-1 completa. Para producción añade almacenamiento externo.
- Los workflows programados en repos públicos se desactivan tras 60 días sin actividad.
- Nunca subas backups ni secretos al repositorio.
