# MedQBank admin console

React dashboard for users, books, and past papers. Served by FastAPI at `/admin`.

## Local development

From `backend/`:

```bash
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

In another terminal:

```bash
cd admin
npm install
npm run dev
```

Open http://localhost:5173/admin/ and sign in with `ADMIN_EMAIL` / `ADMIN_PASSWORD` from `.env`.

## Production

```bash
cd admin
npm ci
npm run build
```

FastAPI serves `admin/dist` at `/admin` after the build.

Render: set `ADMIN_EMAIL` and `ADMIN_PASSWORD`, then build the admin app before starting uvicorn.
