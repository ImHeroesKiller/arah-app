# ARAH Fleet System

Modern fleet command center built with Next.js, Tailwind CSS, MapLibre, Three.js, Framer Motion, and Supabase-ready data access.

## Run locally

```bash
npm install
cp .env.example .env.local
npm run dev
```

Operational data (fleet, orders, routes) is loaded from Supabase — there is no hardcoded demo dataset in the frontend. Seed/demo rows live only in `supabase/migrations/` (latest: `202608010001_demo_10_fleet_routes.sql`). Configure Supabase env vars in `.env.local` / Vercel for a working app.

## Production

```bash
npm run lint
npm run build
```
