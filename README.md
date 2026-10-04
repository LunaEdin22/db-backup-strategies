# db-backup-strategies

**Estudiante:** Edinson Oscar Luna Peña

API mínima en FastAPI + PostgreSQL con backups automatizados: backup lógico
diario, cifrado con GPG, almacenamiento como artifact de GitHub Actions y prueba
de restauración automática. La app y la base de datos corren en Railway.

- **App desplegada:** https://db-backup-strategies-production.up.railway.app/docs
- **Repositorio:** https://github.com/LunaEdin22/db-backup-strategies

## Arquitectura

```
GitHub (código) ──push──▶ Railway: app FastAPI ──red privada──▶ Railway: PostgreSQL 18
                                                                      ▲
GitHub Actions (cron 03:00 UTC) ── URL pública ── pg_dump ────────────┘
        │
        ├─ cifra con GPG ─▶ artifact de GitHub (30 días)
        └─ job restore-test: restaura en un Postgres temporal y verifica filas
```

## Estructura del repositorio

```
db-backup-strategies/
├── app/                      # API FastAPI (main.py, requirements.txt, Dockerfile)
├── scripts/
│   ├── backup.sh             # pg_dump + cifrado GPG
│   └── restore_test.sh       # descifra, restaura y verifica
├── .github/workflows/
│   └── backup.yml            # backup diario + prueba de restauración
├── docker-compose.yml        # desarrollo local
└── README.md
```

## Ejecutar en local

```bash
docker compose up --build
curl -X POST "http://localhost:8000/notes?text=hola"
curl http://localhost:8000/notes
```

Documentación interactiva en http://localhost:8000/docs

## Despliegue en Railway

1. Crea un proyecto y añade **PostgreSQL** (New → Database → PostgreSQL).
2. Añade un servicio desde este repo. En *Settings → Source*, define
   *Root Directory* = `/app`; en *Build*, usa el **Dockerfile**.
3. En las variables del servicio de la app, define
   `DATABASE_URL = ${{Postgres.DATABASE_URL}}` (URL privada, solo para la app).
4. En *Settings → Networking → Generate Domain* de la app, genera el dominio público.
5. En el servicio Postgres, ve a *Settings → Networking → Public Access* y pulsa
   **Add Public Access** (puerto 5432). Luego copia `DATABASE_PUBLIC_URL` desde
   la pestaña *Variables* de Postgres.
6. Cada push a `main` redespliega la app automáticamente.

### Probar la app

En `/docs` (Swagger):

1. `POST /notes` → *Try it out* → escribe un texto → *Execute* (respuesta 200 con el `id`).
2. `GET /notes` → debe listar las notas creadas.
3. `GET /health` → debe responder `{"status":"ok"}`.

Crea al menos una nota antes del primer backup: el test de restauración falla
si la tabla `notes` está vacía.

## Secrets de GitHub

En *Settings → Secrets and variables → Actions → New repository secret*:

| Secret | Descripción |
|---|---|
| `DATABASE_URL` | `DATABASE_PUBLIC_URL` de Postgres en Railway (URL **pública**) |
| `BACKUP_PASSPHRASE` | Contraseña larga para cifrar los backups con GPG |

> Guarda `BACKUP_PASSPHRASE` en un gestor de contraseñas. Sin ella los backups
> cifrados no se pueden recuperar. Nunca pegues estos valores en el repositorio,
> en el chat ni en capturas.

## Backups

- Workflow: `.github/workflows/backup.yml`, diario a las 03:00 UTC.
- Manual: pestaña **Actions → Daily DB Backup → Run workflow**.
- El job `backup` hace `pg_dump` en formato custom, lo cifra con GPG y lo guarda
  como artifact (retención de 30 días; GitHub permite hasta 90).
- El job `restore-test` descarga ese backup, lo restaura en un Postgres temporal
  y falla si la tabla `notes` queda vacía. El log termina con `Filas restauradas: N`.
- `PG_VERSION` del workflow (y la imagen `postgres:` del job de prueba) deben
  coincidir con la versión mayor del servidor. Esta base usa **PostgreSQL 18**.
- El workflow antepone `/usr/lib/postgresql/${PG_VERSION}/bin` al `PATH`, porque
  el runner trae PostgreSQL 16 preinstalado y `pg_dump` fallaría por diferencia
  de versión.

## Restauración manual

1. Descarga el artifact desde la pestaña Actions y descomprímelo.
2. Descífralo (te pedirá la `BACKUP_PASSPHRASE`) y restáuralo. Usa un cliente
   `pg_restore` de versión 18 o superior:

```bash
gpg -o restore.dump -d backup_XXXX.dump.gpg
pg_restore --no-owner -d "URL_DE_LA_BASE_DESTINO" restore.dump
```

## Seguridad

- Public Access expone la base en internet: usa una contraseña larga generada
  al azar (`openssl rand -hex 24`) y rótala si se filtra.
- Al terminar la demostración, desactiva *Public Access* en Railway.
- Los backups viajan y se almacenan cifrados; el dump sin cifrar se elimina del runner.

## Limitaciones (demo)

- Los artifacts viven en GitHub: la copia está fuera de Railway, pero no cumple
  la regla 3-2-1 completa. Para producción añade almacenamiento externo.
- El tráfico por Public Access se factura como egress en Railway (mínimo en esta demo).
- Los workflows programados en repos públicos se desactivan tras 60 días sin actividad.
- Nunca subas backups ni secretos al repositorio.
