# Amina Travel — Development & Deployment Plan

> An online travel agency (OTA) platform in the style of tunisiebooking.com:
> hotels, flights, organized trips, car rental, cruises, Umrah/Hajj, and ticketing —
> with online payment, multi-language, and multi-currency support.

---

## 1. Product Vision & Scope

**Amina Travel** is a booking platform + agency back-office for the Tunisian / North-African market
(expandable to international). Two audiences:

- **B2C** — travellers browse, search, book and pay online (web + mobile).
- **B2B / internal** — agency staff manage inventory, bookings, suppliers, payments and reporting.

### Feature parity with TunisieBooking (grouped by domain)

| Domain | Features |
|---|---|
| **Hotels** | Search by destination/date/occupancy, filters (stars, board, price, amenities), room/board selection, availability & pricing, reviews, maps, "best price" promos |
| **Flights** | One-way / round-trip / multi-city search, low-cost + regular carriers, fare rules, baggage, seat selection |
| **Organized trips** (Voyages organisés) | Curated packages/circuits (Turkey, Egypt, Morocco, Europe, domestic), fixed departures, itinerary, inclusions, group pricing |
| **Car rental** | Location by city/airport, date range, vehicle class, insurance options |
| **Cruises** (Croisières) | Cabin selection, itineraries, departure dates |
| **Umrah / Hajj** | Seasonal packages, visa handling, flight+hotel+transfer bundles |
| **Ticketing** (Billetterie) | Ferry crossings, events, transfers |
| **Cross-cutting** | Accounts & profiles, wishlists, reviews & ratings, loyalty, promo codes, online payment, e-vouchers/e-tickets (PDF), multi-currency, multi-language (FR / AR-RTL / EN), 7/7 support/chat, agency locator |

---

## 2. Recommended Tech Stack

Chosen to **reuse your existing .NET expertise** (the Contably stack) so patterns, tooling and CI carry over.

| Layer | Choice | Rationale |
|---|---|---|
| **Backend** | .NET 9, ASP.NET Core **Minimal APIs**, **modular monolith** | Same architecture you already run in Contably; fast to build, easy to split later |
| **DB** | PostgreSQL 16 + EF Core 9 (schema-per-module) | Familiar; strong for transactional booking data |
| **Search** | OpenSearch / Elasticsearch | Hotel & package faceted search, geo, autocomplete — RDBMS won't scale for this |
| **Cache / sessions** | Redis | Price caching (supplier quotes expire fast), rate-limiting, distributed locks on inventory |
| **Auth/Identity** | TBD — e.g. ASP.NET Core Identity + JWT | Social login, roles (customer/agent/admin) |
| **Async / events** | Transactional outbox + RabbitMQ (or MassTransit) | Booking → payment → ticketing saga, supplier callbacks |
| **Web frontend** | **Next.js (React) + TypeScript**, SSR/ISR | Travel is **SEO-critical**; SSR + Tailwind, i18n (FR/AR/EN, RTL) |
| **Mobile** | Phase 2: React Native (shared TS) or responsive PWA first | Defer native until web validated |
| **Files/media** | Cloudinary or S3-compatible (MinIO) | Hotel imagery, e-voucher PDFs |
| **PDF** | QuestPDF | Vouchers, e-tickets, invoices (already used in Contably) |
| **Infra** | Docker + Docker Compose (dev) → Kubernetes (prod) | Matches your GitLab CI/CD workflow |

> **Key strategic decision (biggest one):** how you source inventory. See §4.

---

## 3. Architecture (modular monolith → service-ready)

```
                  ┌────────────────────────────────────────┐
   Web (Next.js)  │            BFF / API Gateway            │  (YARP, like Contably)
   Mobile (later) │   auth, rate-limit, aggregation, i18n   │
                  └───────────────────┬────────────────────┘
                                      │
        ┌─────────────────────────────┼─────────────────────────────┐
        │                Amina Travel Modular Monolith               │
        │  Search │ Hotels │ Flights │ Packages │ Cars │ Cruises     │
        │  Cart/Booking │ Pricing │ Payments │ Ticketing/Vouchers    │
        │  Customers │ Reviews │ Promotions │ CMS │ Notifications     │
        │  Agency Back-office │ Suppliers │ Reporting                 │
        └───┬───────────┬───────────┬───────────┬───────────┬────────┘
            │           │           │           │           │
        PostgreSQL   OpenSearch   Redis     RabbitMQ    Supplier APIs
                                                        (GDS, bedbanks,
                                                         payment gateways)
```

**Core modules**

- **Search** — unified index over hotels/packages; faceted, geo, autocomplete.
- **Product modules** (Hotels, Flights, Packages, Cars, Cruises, Umrah, Ticketing) — each owns catalog, availability, pricing rules.
- **Cart & Booking** — the transactional heart: hold inventory, orchestrate a **saga** (quote → hold → pay → confirm → issue voucher/ticket), handle partial failures & refunds.
- **Pricing engine** — markups, commissions, promo codes, currency conversion, tax.
- **Payments** — pluggable gateways (see §4), 3-D Secure, webhooks, reconciliation.
- **Customers / Auth** — profiles, KYC for Umrah/visa, loyalty.
- **Notifications** — email (MimeKit), SMS, WhatsApp; booking confirmations.
- **Agency back-office** — inventory & package authoring, manual bookings, supplier & commission management, refunds, reporting.
- **CMS** — landing pages, destinations, SEO content, banners/promos.

---

## 4. Third-Party Integrations — the make-or-break of an OTA

You **cannot** manually maintain live hotel/flight inventory. Decide build-vs-connect early.

**Inventory suppliers**
- **Flights:** a GDS/NDC aggregator — Amadeus Self-Service / Travelport / Sabre, or an aggregator like Duffel or Kiwi.com (Tequila). Duffel is fastest to integrate for a startup.
- **Hotels:** bed-bank / channel APIs — **Hotelbeds (APItude)**, **TBO**, or Expedia Rapid (EPS). TBO & Hotelbeds are common in the MENA market.
- **Cars:** CarTrawler or direct supplier feeds.
- **Cruises / Ferries:** usually direct contracts or CTN/GNV (ferries) — often manually managed at MVP.

**Payments (Tunisia-first)**
- Local: **Clictopay / SMT (Monétique Tunisie)**, **e-Dinar (La Poste)**, **Konnect**, **Flouci**.
- International cards: **Stripe** or **Adyen** (for diaspora / foreign buyers).
- Design payments as a **provider abstraction** so gateways are swappable per currency/region.

**Other:** Google Maps (geo/maps), an SMS provider, WhatsApp Business API, a review source, currency-rate feed (ECB/fixer), analytics (GA4 + server-side).

---

## 5. Data Model — high-value entities (per module)

- **Hotel:** Hotel, RoomType, BoardType, RatePlan, AvailabilityCache, Amenity, Review, Destination(geo).
- **Flight:** Search, FareOffer, Segment, Passenger, Baggage, Booking(PNR).
- **Package:** Package, Departure, Itinerary, InclusionExclusion, PriceTier, SeatInventory.
- **Booking (shared):** Cart, BookingOrder, BookingItem(polymorphic), Traveller, Payment, Voucher, Refund, StatusHistory.
- **Pricing:** Markup, Commission, PromoCode, CurrencyRate, TaxRule.
- **Supplier:** Supplier, SupplierCredential, SupplierMapping, ReconciliationRecord.

Booking status flow (saga): `Draft → Quoted → Held → PaymentPending → Confirmed → Ticketed → Completed` (with `Failed / Cancelled / Refunded` branches).

---

## 6. Delivery Roadmap (phased)

### Phase 0 — Foundations (2–3 wks)
Repo & solution scaffold, CI/CD, Docker Compose (Postgres/Redis/OpenSearch/RabbitMQ), auth, tenancy/config, i18n skeleton (FR/AR/EN), design system, error handling, observability baseline (OpenTelemetry + Loki + Prometheus — same as Contably).

### Phase 1 — MVP: Hotels + Booking + Payments (6–8 wks) ⭐
The single vertical that proves the platform end-to-end.
- Hotel search (one bed-bank supplier, e.g. TBO/Hotelbeds) → results → detail → book → **pay online** → e-voucher PDF + email.
- Customer accounts, booking history, one payment gateway (Clictopay + one card gateway).
- Basic agency back-office (view/manage bookings, refund).
- SEO-ready landing + destination pages.
**Milestone: first real paid booking.**

### Phase 2 — Organized Trips + Flights (5–7 wks)
- Package/circuit authoring in back-office + fixed-departure booking (high margin, fully controllable — good early revenue).
- Flight search via aggregator (Duffel), combine flight+hotel bundles.

### Phase 3 — Breadth: Cars, Cruises, Umrah, Ticketing (5–7 wks)
- Car rental supplier, cruise/ferry (manual + API), Umrah packages with traveller KYC/visa docs.
- Promo codes, loyalty, reviews, wishlists.

### Phase 4 — Scale & polish (ongoing)
- Multi-currency everywhere, additional suppliers & payment gateways, mobile app/PWA, recommendation & upsell, A/B testing, performance/SEO hardening, agency network / multi-branch.

*Indicative total to a marketable product: ~5–7 months with a small focused team.*

---

## 7. Suggested Team

- 1 Tech lead / architect (you)
- 2 Backend (.NET) engineers
- 2 Frontend (Next.js) engineers
- 1 QA (booking flows are high-risk — automate them)
- 0.5 DevOps (CI/CD, k8s, observability)
- 1 Product/UX + content (destinations, SEO, translations FR/AR)

---

## 8. Deployment & Infrastructure

**Environments:** `local` (Compose) → `dev` → `staging` → `prod`, promoted via GitLab CI/CD (mirrors Contably).

**CI/CD pipeline:** build → unit + integration tests → container build → security scan (Trivy/Dependabot) → deploy to staging → smoke tests → manual gate → prod.

**Production topology (Kubernetes):**
- API (HPA-autoscaled), Next.js (SSR pods or Vercel/Node), OpenSearch cluster, managed PostgreSQL (with read replica), Redis, RabbitMQ, MinIO/S3.
- **CDN** (Cloudflare) in front of web + media — critical for image-heavy travel pages and DDoS/WAF.
- Blue-green or canary deploys; DB migrations gated & backward-compatible.

**Observability:** OpenTelemetry traces (essential for multi-supplier booking sagas), Prometheus metrics, Loki logs, alerting on payment failures / supplier timeouts / booking-saga stalls.

**Backups & DR:** PITR on Postgres, daily snapshots, tested restore runbook. Booking + payment data is money — no data loss tolerance.

---

## 9. Security, Compliance & Legal

- **PCI-DSS:** never store raw card data — use hosted fields / tokenization from gateways (keeps you in SAQ-A scope).
- **3-D Secure** on all card payments; idempotency keys on payment + booking endpoints (double-click / retry safety).
- **Data protection:** Tunisian INPDP (loi 2004-63) + GDPR for EU/diaspora customers; consent, data export/erasure.
- **Travel-specific:** clear cancellation/refund policy per product, supplier fare-rule display, e-voucher terms, IATA/agency licensing for flight ticketing.
- **Auth:** RBAC (customer/agent/admin/finance), MFA for staff, rate limiting, audit log on back-office actions.

---

## 10. Top Risks & Mitigations

| Risk | Mitigation |
|---|---|
| **Supplier integration complexity** (biggest) | Start with ONE hotel supplier; build a supplier-abstraction layer; sandbox first |
| Price/availability drift (quotes expire) | Re-validate price at booking; short Redis TTL caches; show "price may change" |
| Payment failures / double charges | Sagas + idempotency + reconciliation jobs + webhook-driven confirmation |
| SEO underperformance | SSR/ISR from day 1, structured data, fast CDN, real content |
| Booking-flow bugs = lost money | Heavy automated E2E tests on the pay/confirm/refund paths |
| Overbuilding breadth too early | MVP = hotels only; add domains once the core is proven |

---

## 11. Immediate Next Steps

1. **Confirm scope & the two big decisions:** (a) which product is the MVP vertical (recommend **Hotels**), (b) which suppliers & payment gateways to pilot.
2. Scaffold the solution (backend modular monolith + Next.js web) and the Docker Compose dev stack.
3. Sign up for **supplier sandboxes** (e.g. Hotelbeds/TBO, Duffel) and a **payment sandbox** (Clictopay + Stripe) — integration lead time is the long pole.
4. Build the Phase-1 hotel booking vertical end-to-end.

---

### Sources
- [TunisieBooking — home](https://tn.tunisiebooking.com/)
- [Voyages Organisés 2026](https://tn.tunisiebooking.com/voyage_organise/)
- [Agency network](https://tn.tunisiebooking.com/nos_agences.html)
