# Amina Travel — DevOps / Infrastructure Spec

**Audience:** DevOps / platform engineer provisioning, deploying and operating the stack.
**Scope:** infrastructure, runtimes, build, config, networking, data. **No business logic.**
**Verified against the repo** (parent + `backend` + `front` submodules) on branch `dev`.

> This is the source of truth for ops. The older `DEPLOYMENT.md` at the repo root is **stale**
> (it still lists Redis/OpenSearch/RabbitMQ, which were removed as unused) — prefer this file.

---

## 1. Architecture at a glance

The system is **three deployable processes** plus **one database**. It is a modular monolith,
not microservices — the whole backend is a single process.

```
                 ┌──────────────────┐   ┌──────────────────┐
   browser  ───► │  Website (SSR)   │   │  Admin panel     │  ◄── staff
                 │  Next.js :3000   │   │  Next.js :3001   │
                 └────────┬─────────┘   └────────┬─────────┘
                          │  HTTP (REST/JSON)     │
                          └───────────┬───────────┘
                                      ▼
                           ┌──────────────────────┐        outbound HTTPS
                           │   API (.NET 9)        │ ─────► TunisiaBeds (hotels)
                           │   ASP.NET Core :8080  │ ─────► Clictopay (payments)
                           │   modular monolith    │ ─────► Cloudinary (images)
                           └──────────┬───────────┘ ─────► SMTP/Gmail (contact)
                                      ▼
                           ┌──────────────────────┐
                           │  PostgreSQL 16        │  one DB, 7 schemas
                           │  amina_travel :5432   │  (schema-per-module)
                           └──────────────────────┘
```

**No message broker, no cache, no search cluster.** Redis / RabbitMQ / OpenSearch were scaffolded
but never wired to any code, and have been removed. Do **not** provision them.

---

## 2. Components & runtimes

| Component | Runtime | Framework | Container port | Host port (dev) | Dockerfile |
|-----------|---------|-----------|----------------|-----------------|------------|
| **API** | .NET 9 (`aspnet:9.0`) | ASP.NET Core minimal APIs | 8080 | 5080 | `backend/Dockerfile` |
| **Website** | Node 22 (`node:22-alpine`) | Next.js 16 (standalone) | 3000 | 3000 | `front/apps/website/Dockerfile` |
| **Admin** | Node 22 (`node:22-alpine`) | Next.js 16 (standalone) | 3001 | 3001 | `front/apps/admin/Dockerfile` |
| **PostgreSQL** | Postgres 16-alpine | — | 5432 | 5432 | official image |

- The frontend is an **npm-workspaces monorepo** (`front/`): `apps/website`, `apps/admin`, and
  shared `packages/*`. Package manager: **npm 10**. Both apps build to Next.js **`output: "standalone"`**.
- Both frontend Dockerfiles **must be built with the front repo root as build context** (they need
  the root lockfile + `packages/*`), e.g. `docker build -f apps/website/Dockerfile ./front`.
- The API is a single self-contained process (`dotnet Amina.Travel.Api.dll`). Stateless — all state
  is in Postgres. Safe to run behind a load balancer (see §9 caveat on migrations).

---

## 3. Data store

- **One PostgreSQL 16 database:** `amina_travel`.
- **Schema-per-module** (7 schemas), selected via `SearchPath` in each connection string:
  `hotels`, `auth`, `promos`, `bookings`, `voyages`, `reservations`, `payments`.
- Each module has its own connection string env var (see §5) — all point at the **same** database,
  differing only by `SearchPath`. This lets you split modules onto separate DBs later without code changes.
- **Migrations & seed data run automatically on API startup** (EF Core `MigrateAsync`). There is **no
  separate migration job** — the API creates/updates all schemas itself when it boots. First boot also
  seeds reference/admin data.
- Persistent volume: `pgdata` (Postgres data dir). This is the **only** stateful volume.

---

## 4. Networking & ports

| From | To | Address | Notes |
|------|----|---------|-------|
| Browser | API | `NEXT_PUBLIC_API_BASE_URL` (dev: `http://localhost:5080`) | Baked into the **website client bundle at build time** (build arg) |
| Website SSR (server) | API | `API_URL_INTERNAL` (compose: `http://api:8080`) | In-container, over the private network |
| API | PostgreSQL | `Host=postgres;Port=5432` | Connection strings |
| API | Internet | HTTPS 443 | TunisiaBeds, Clictopay, Cloudinary, SMTP (587) |

- **CORS** on the API is an allow-list (`Cors:Origins`). Default allows only `http://localhost:3000`.
  In prod you **must** add the real website + admin origins or the browser calls fail.
- `NEXT_PUBLIC_API_BASE_URL` is **compile-time** for the website (it lands in the JS shipped to the
  browser). Changing the API URL requires a **rebuild** of the website image, not just a restart.

---

## 5. Configuration (environment variables)

The API reads standard .NET config. **Nested keys use `__` (double underscore)** in env vars,
e.g. `Payments__Clictopay__UserName` → `Payments:Clictopay:UserName`.

### 5.1 API — required

| Variable | Example | Purpose |
|----------|---------|---------|
| `ASPNETCORE_ENVIRONMENT` | `Production` | .NET environment |
| `Kestrel__Endpoints__Http__Url` | `http://0.0.0.0:8080` | Bind address (or `ASPNETCORE_URLS`) |
| `ConnectionStrings__HotelsDb` | `Host=…;Database=amina_travel;Username=…;Password=…;SearchPath=hotels` | Hotels schema |
| `ConnectionStrings__AuthDb` | …`SearchPath=auth` | Auth schema |
| `ConnectionStrings__PromosDb` | …`SearchPath=promos` | Promos schema |
| `ConnectionStrings__BookingsDb` | …`SearchPath=bookings` | Bookings schema |
| `ConnectionStrings__VoyagesDb` | …`SearchPath=voyages` | Voyages schema |
| `ConnectionStrings__ReservationsDb` | …`SearchPath=reservations` | Reservations schema |
| `ConnectionStrings__PaymentsDb` | …`SearchPath=payments` | Payments schema |
| `Cors__Origins__0` | `https://www.aminatravel.tn` | Allowed browser origin(s); add `__1`, `__2`… |

### 5.2 API — integrations (all degrade gracefully if empty)

| Variable | If empty | Purpose |
|----------|----------|---------|
| `Hotels__TunisiaBeds__Login` / `__Password` | hotel catalog/pricing unavailable | Hotel supplier API (`https://admin.tunisiabeds.tn/api/hotel`) |
| `Payments__Clictopay__UserName` / `__Password` | falls back to **in-site mock bank page** | Online payment gateway |
| `Payments__Clictopay__BaseUrl` | `https://test.clictopay.com` | Sandbox vs prod gateway URL |
| `Payments__Clictopay__WebBaseUrl` | — | Where the gateway redirects the customer back (the website base URL) |
| `Payments__OnlineEnabled` | `false` (default) | Master switch for online payments |
| `Cloudinary__Url` | image uploads return **503** | Admin image uploads (`cloudinary://key:secret@cloud`) |
| `Smtp__User` / `Smtp__Password` | contact form returns **503** | Contact form email (Gmail needs an **app password**) |
| `Smtp__Host` / `Smtp__Port` / `Smtp__To` | `smtp.gmail.com` / `587` / configured | SMTP target |

> **Default deposit** and currency (`Payments:DepositPercent`, `Clictopay:Currency=788` TND,
> `Language=fr`) live in `appsettings.json` and rarely need env overrides.

### 5.3 Frontend

| Variable | Where | Purpose |
|----------|-------|---------|
| `NEXT_PUBLIC_API_BASE_URL` | **build arg** (both apps) | API URL baked into the browser bundle |
| `API_URL_INTERNAL` | runtime (SSR) | In-cluster API address for server-side fetches |
| `NODE_ENV=production` | runtime | Set by the Dockerfiles |

---

## 6. Build & deploy

### API
```bash
# context = backend/ ; multi-stage (sdk build -> aspnet runtime)
docker build -t amina-api ./backend
docker run -p 5080:8080 --env-file api.env amina-api
```
Migrations apply themselves on boot — no extra step.

### Website / Admin (context = front repo root)
```bash
docker build -f front/apps/website/Dockerfile \
  --build-arg NEXT_PUBLIC_API_BASE_URL=https://api.aminatravel.tn \
  -t amina-web ./front

docker build -f front/apps/admin/Dockerfile \
  --build-arg NEXT_PUBLIC_API_BASE_URL=https://api.aminatravel.tn \
  -t amina-admin ./front
```
Runtime entrypoints: `node apps/website/server.js` / `node apps/admin/server.js` (standalone output).

### Local dev (parent repo)
```bash
make init      # build images + start whole stack, then health-check
make up        # start stack (app profile: api + web + postgres)
make infra     # start only Postgres
make down      # stop & remove containers
make clean     # stop + delete volumes (DESTROYS local DB)
make logs-api  # tail API logs
```

---

## 7. Health checks & observability

- **API liveness/readiness:** `GET /health` → `200 {"status":"ok","service":"amina-travel-api"}`.
  Use for LB health probes and k8s liveness/readiness.
- **Postgres:** `pg_isready -U amina -d amina_travel` (already the compose healthcheck).
- **Frontend:** Next.js standalone serves on its port; probe `GET /` (no dedicated health route).
- **Logging:** .NET default console logging (`Logging:LogLevel:Default = Information`) → stdout.
  Frontend logs → stdout. Ship container stdout to your log stack.
- There is **no metrics endpoint / APM** wired in. If you need Prometheus/OTel, it must be added.

---

## 8. Secrets

Config is plain env vars — inject via your secret manager (k8s Secrets, SSM, Vault, etc.).
The sensitive ones: all `ConnectionStrings__*` passwords, `Hotels__TunisiaBeds__Password`,
`Payments__Clictopay__Password`, `Cloudinary__Url`, `Smtp__Password`.

> ⚠️ **Action required — see §10 item 1: real production-looking secrets are currently committed
> in `.env.example`. They must be rotated and scrubbed.**

---

## 9. Scaling & operational notes

- **API is stateless** → horizontally scalable behind an LB, *except* the startup-migration caveat:
  every replica runs `MigrateAsync` on boot. Concurrent first-boot of multiple replicas can race on
  DDL. Mitigation: run **one replica first** (or a dedicated init/migration step) until schemas exist,
  then scale out. EF migrations are idempotent, so steady-state rolling deploys are fine.
- **Frontend apps are stateless** → scale freely.
- **Postgres** is the single stateful component → back up `pgdata` / use managed Postgres with PITR.
- **Sticky sessions not required** (JWT/cookie auth is stateless; no server-side session store).

---

## 10. ⚠️ Known gaps to resolve before / during handoff

1. **🔴 Committed secrets.** `.env.example` (tracked in git) contains what look like **real**
   credentials: a Cloudinary URL with API secret, the TunisiaBeds password, and a Gmail app password.
   **Rotate all three** and replace the values with empty placeholders. Consider `git filter-repo`/
   history scrub if the repo is or will be shared.
2. **🟠 `docker-compose` web build is broken.** The `web` service uses `build.context: ./front` with
   **no `dockerfile:`**, so Compose looks for `front/Dockerfile`, which does not exist (the Dockerfiles
   are `front/apps/website/Dockerfile` and `.../admin/Dockerfile`). `make up` will fail to build web.
   Fix: add `dockerfile: apps/website/Dockerfile` to the `web` service.
3. **🟠 Admin app is not in `docker-compose`.** Only website is referenced. The admin panel (port 3001)
   has a Dockerfile but no compose service / deployment manifest — add one for any environment that
   needs admin.
4. **🟡 Stale Makefile.** The `make infra` help text still says *"postgres, redis, opensearch, rabbitmq"*
   — only Postgres remains. Cosmetic, but update it.
5. **🟡 Stale `DEPLOYMENT.md`.** The older root doc provisions Redis/OpenSearch/RabbitMQ and tells you to
   "create front/Dockerfile". Delete or replace it with this file to avoid provisioning phantom infra.
6. **🟡 No CI/CD, no k8s/Terraform manifests** in-repo. Compose is dev-only; production orchestration
   (registry, deploy manifests, TLS/ingress, backups) is greenfield.

---

## 11. Minimum production checklist

- [ ] Provision: managed Postgres 16, container runtime/orchestrator, LB + TLS termination.
- [ ] Rotate & inject all secrets from a secret manager; scrub `.env.example`.
- [ ] Set `ASPNETCORE_ENVIRONMENT=Production`.
- [ ] Set `Cors__Origins__*` to the real website + admin domains.
- [ ] Build website/admin with the **production** `NEXT_PUBLIC_API_BASE_URL` (compile-time!).
- [ ] Set `Payments__Clictopay__*` (prod URL + creds) and `OnlineEnabled=true` when going live with online pay.
- [ ] Point `Payments__Clictopay__WebBaseUrl` at the real website URL.
- [ ] Wire `/health` into LB/orchestrator probes.
- [ ] First deploy: single API replica (migrations), then scale.
- [ ] Backups + PITR on Postgres; test restore.
- [ ] Ship stdout logs to a central store.
```
