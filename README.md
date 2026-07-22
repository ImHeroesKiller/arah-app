# ARAH Fleet System

Modern fleet command center built with Next.js, Tailwind CSS, MapLibre, Three.js, Framer Motion, and Supabase-ready data access.

## Run locally

```bash
npm install
cp .env.example .env.local
npm run dev
```

The app runs with realistic demo data if Supabase variables are absent. Configure the variables listed in `.env.example` in Vercel when the backend is ready.

## Production

```bash
npm run lint
npm run build
```
