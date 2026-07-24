# Amina Travel — Production Deployment Runbook

Single-VPS deployment: Docker Compose (Postgres + API + website + admin + nginx) behind Cloudflare.

- **Website** → `https://‹domain›`
- **Admin** → `https://admin.‹domain›`
- **API** → `https://api.‹domain›`

---

## 0. Prerequisites on the VPS (one-time)

```bash
# Docker Engine + Compose plugin (Debian/Ubuntu)
curl -fsSL https://get.docker.com | sh
docker --version && docker compose version

# open the firewall for web traffic only (SSH stays as-is)
ufw allow 80/tcp && ufw allow 443/tcp
```
DNS/TLS terminate at Cloudflare (§4). The origin only needs 80 (and 443 once the origin cert is in).

---

## 1. Get the code

The repo uses git submodules (`backend`, `front`), so clone **recursively**.

```bash
cd /opt
git clone --recurse-submodules \
  https://<GITHUB_PAT>@github.com/ghassen-git/amina-travel.git
cd amina-travel
git checkout main
git submodule update --init --recursive
```
> Use the PAT only for the clone. **Rotate/revoke it afterwards.** To avoid caching it on disk:
> `git clone ...` then `git remote set-url origin https://github.com/ghassen-git/amina-travel.git`

---

## 2. Configure

```bash
cd /opt/amina-travel/deploy
cp .env.production.example .env
nano .env        # set DOMAIN + a strong POSTGRES_PASSWORD, paste integration secrets
```
`DOMAIN` is baked into the frontend build — set it **before** building. Changing it later requires a rebuild.

---

## 3. Build & start

```bash
cd /opt/amina-travel/deploy
docker compose -f docker-compose.prod.yml --env-file .env up -d --build
```
The API auto-applies all DB migrations and seeds on first boot. Watch it come up:

```bash
docker compose -f docker-compose.prod.yml ps
docker compose -f docker-compose.prod.yml logs -f api      # Ctrl-C to stop tailing
```

### Verify (from the VPS, before DNS is live)
```bash
curl -s -H 'Host: api.‹domain›' http://localhost/health          # {"status":"ok",...}
curl -s -o /dev/null -w '%{http_code}\n' -H 'Host: ‹domain›'       http://localhost/   # 200
curl -s -o /dev/null -w '%{http_code}\n' -H 'Host: admin.‹domain›' http://localhost/   # 200
```

---

## 4. Cloudflare

### 4.1 DNS records (Cloudflare dashboard → DNS)
Add four **proxied** (orange cloud) A records, all pointing at the VPS IP `162.35.185.169`:

| Type | Name    | Content           | Proxy |
|------|---------|-------------------|-------|
| A    | `@`     | `162.35.185.169`  | 🟠 Proxied |
| A    | `www`   | `162.35.185.169`  | 🟠 Proxied |
| A    | `admin` | `162.35.185.169`  | 🟠 Proxied |
| A    | `api`   | `162.35.185.169`  | 🟠 Proxied |

### 4.2 SSL/TLS mode
SSL/TLS → Overview. Two options:

- **Full (strict)** — *recommended.* Encrypts Cloudflare→origin and validates the cert. Requires an
  origin certificate on nginx (§4.3).
- **Flexible** — *quick start only.* Cloudflare→origin is plain HTTP:80. Works with the current
  port-80 nginx as-is, but traffic between Cloudflare and your VPS is unencrypted. Fine to launch on,
  then upgrade to Full (strict).

### 4.3 Enable Full (strict) — origin certificate
1. Cloudflare → SSL/TLS → **Origin Server** → **Create Certificate** (covers `‹domain›`, `*.‹domain›`).
2. Save the cert and key on the VPS:
   ```bash
   mkdir -p /opt/amina-travel/deploy/nginx/certs
   nano /opt/amina-travel/deploy/nginx/certs/fullchain.pem   # paste the certificate
   nano /opt/amina-travel/deploy/nginx/certs/privkey.pem     # paste the private key
   ```
3. In `docker-compose.prod.yml`, **uncomment**: the `- "443:443"` port and the `./nginx/certs` volume.
4. Add a TLS server block — copy `nginx/templates/amina.conf.template` blocks and add, per server:
   ```nginx
   listen 443 ssl;
   ssl_certificate     /etc/nginx/certs/fullchain.pem;
   ssl_certificate_key /etc/nginx/certs/privkey.pem;
   ```
   (A ready `tls.conf.template` can be generated on request.)
5. `docker compose -f docker-compose.prod.yml up -d` to reload nginx.
6. Turn on **Always Use HTTPS** and **Automatic HTTPS Rewrites** in Cloudflare.

### 4.4 Restore real visitor IPs (optional)
Behind Cloudflare, nginx sees Cloudflare IPs. To log the real client IP, add Cloudflare's IP ranges
with `set_real_ip_from` + `real_ip_header CF-Connecting-IP` to the nginx template. Ask and I'll add it.

---

## 5. 🔒 Protecting the admin portal (`admin.‹domain›`)

The admin app already requires an app login, but you should also gate it at the edge so the panel
isn't publicly reachable at all. **Cloudflare Zero Trust → Access** (free up to 50 users):

1. Cloudflare dashboard → **Zero Trust** → **Access** → **Applications** → **Add an application** → *Self-hosted*.
2. Application domain: `admin.‹domain›`.
3. **Policy**: Action *Allow*, rule e.g. *Emails* → your staff addresses (or *Emails ending in* `@aminatravel.tn`).
4. Save. Now hitting `admin.‹domain›` shows a Cloudflare login (email OTP / Google SSO) **before** the
   request ever reaches your VPS. Only approved staff get through, then the app's own login applies.

Extra hardening options:
- Cloudflare **WAF** rule to block `api.‹domain›` paths that should be admin-only (or geo-restrict).
- Rate-limiting rules on `api.‹domain›/api/auth/login`.

---

## 6. Operations

```bash
cd /opt/amina-travel/deploy
COMPOSE="docker compose -f docker-compose.prod.yml"

$COMPOSE ps                 # status
$COMPOSE logs -f api        # tail a service
$COMPOSE restart web admin  # restart frontends
$COMPOSE down               # stop (keeps the DB volume)
```

### Update / redeploy
```bash
cd /opt/amina-travel
git pull && git submodule update --init --recursive
cd deploy && docker compose -f docker-compose.prod.yml --env-file .env up -d --build
```

### Database backup / restore
```bash
# backup
docker exec amina-postgres pg_dump -U amina amina_travel | gzip > backup-$(date +%F).sql.gz
# restore
gunzip -c backup-YYYY-MM-DD.sql.gz | docker exec -i amina-postgres psql -U amina -d amina_travel
```
Schedule the backup via cron and copy off-box. The `pgdata` volume is the only stateful data.

---

## 7. First-launch checklist
- [ ] `.env` filled: `DOMAIN`, strong `POSTGRES_PASSWORD`, integration secrets.
- [ ] `up -d --build` succeeded; `/health` returns ok.
- [ ] 4 Cloudflare A records (proxied); SSL mode set.
- [ ] Full (strict) + origin cert + 443 enabled (or launched on Flexible, upgrade planned).
- [ ] Cloudflare Access protecting `admin.‹domain›`.
- [ ] Changed the seeded admin password (`admin@amina.travel` / `Admin123!`) via the admin panel.
- [ ] Postgres backup cron in place.
