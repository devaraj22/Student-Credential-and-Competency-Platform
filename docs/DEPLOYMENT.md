# Production Deployment Guide: Render (Backend) & Vercel (Frontend)

This guide walks through deploying the **Student Credential & Competency Platform** to production with **Render** hosting the FastAPI backend and PostgreSQL database, and **Vercel** hosting the React + Vite frontend.

---

## Architecture Overview

```
                      +-----------------------------+
                      |       User Browser          |
                      +-----------------------------+
                                     |
                                     | HTTPS (Single Domain)
                                     v
                      +-----------------------------+
                      |      Vercel (Frontend)      |
                      |  - React 18 + Vite SPA      |
                      |  - Client Routing (/*)      |
                      +-----------------------------+
                                     |
                                     | /api/* (Vercel Edge Rewrite Proxy)
                                     v
                      +-----------------------------+
                      |       Render (Backend)      |
                      |  - FastAPI (Python 3.12)    |
                      |  - Uvicorn on 0.0.0.0:$PORT |
                      +-----------------------------+
                                     |
                                     v
                      +-----------------------------+
                      |   Render Managed Postgres   |
                      |  - skilltrack database      |
                      |  - Alembic migrations       |
                      +-----------------------------+
```

### Why Same-Origin Vercel Rewrites?
The platform uses **HttpOnly, Secure session cookies** with double-submit **CSRF tokens** for maximum security.
By configuring Vercel to reverse-proxy `/api/:path*` to the Render backend, the browser sees a **single unified origin**:
- No third-party cookie blocking in modern browsers (Chrome, Safari ITP).
- The frontend JavaScript can read `csrf_token` cookie on its own origin.
- Zero credentials stored in `localStorage`.

---

## Step 1: Deploy Backend & Database on Render

### Method A: Automated via Render Blueprint (Recommended)
The repository includes a ready-to-go `render.yaml` blueprint.

1. Push your latest code to your GitHub repository:
   ```powershell
   git add .
   git commit -m "chore(deploy): add Render blueprint and Vercel configuration"
   git push origin main
   ```
2. Log in to [Render Dashboard](https://dashboard.render.com/).
3. Click **New +** > **Blueprint**.
4. Connect your GitHub repository (`Skill-Tracker`).
5. Render will detect `render.yaml` and display:
   - **skilltrack-db**: Managed PostgreSQL database.
   - **skilltrack-api**: Python Web Service.
6. Click **Apply**.
7. Once deployed, copy your backend URL from Render (e.g., `https://skilltrack-api.onrender.com`).

---

### Method B: Manual Web Service Setup on Render

1. **Create PostgreSQL Database**:
   - In Render, click **New +** > **PostgreSQL**.
   - Name: `skilltrack-db`
   - Database: `skilltrack`
   - User: `skilltrack`
   - Plan: **Free**
   - Click **Create Database** and copy the **Internal Database URL**.

2. **Create Web Service**:
   - Click **New +** > **Web Service**.
   - Connect your GitHub repository.
   - **Root Directory**: `backend`
   - **Runtime**: `Python 3`
   - **Build Command**: `pip install -r requirements.txt && alembic upgrade head`
   - **Start Command**: `uvicorn app.main:app --host 0.0.0.0 --port $PORT`
   - **Health Check Path**: `/health`

3. **Configure Environment Variables in Render**:
   | Variable | Value / Description |
   |---|---|
   | `APP_ENV` | `production` |
   | `PYTHON_VERSION` | `3.12.0` |
   | `DATABASE_URL` | Paste Render PostgreSQL connection string |
   | `SECRET_KEY` | At least 32 random characters (Render can auto-generate) |
   | `ACCESS_TOKEN_MINUTES` | `60` |
   | `COOKIE_SAMESITE` | `lax` |
   | `CORS_ORIGINS` | `http://localhost:5173,https://<your-vercel-domain>.vercel.app` |

---

## Step 2: Create the Initial Administrator on Render

Public registration only creates student accounts. To create your college administrator on Render:

1. In the Render Dashboard, open your `skilltrack-api` service.
2. Click **Shell** in the left sidebar to open a terminal.
3. Run the admin creation command:
   ```bash
   python -m app.cli create-admin --email admin@yourcollege.edu
   ```
4. Enter and confirm your administrator password when prompted.

---

## Step 3: Deploy Frontend on Vercel

1. Log in to [Vercel Dashboard](https://vercel.com/dashboard).
2. Click **Add New...** > **Project**.
3. Import your GitHub repository (`Skill-Tracker`).
4. In the Project Configuration:
   - **Framework Preset**: `Vite`
   - **Root Directory**: `frontend` (or leave as `./` if using root `vercel.json`)
   - **Build Command**: `npm run build`
   - **Output Directory**: `dist`
5. In `frontend/vercel.json` (and root `vercel.json`):
   Update the destination in the rewrite rule with your actual Render backend URL:
   ```json
   {
     "rewrites": [
       {
         "source": "/api/:path*",
         "destination": "https://<your-render-service-name>.onrender.com/api/:path*"
       },
       {
         "source": "/(.*)",
         "destination": "/index.html"
       }
     ]
   }
   ```
6. Click **Deploy**.
7. Once deployed, Vercel gives you your live URL (e.g., `https://skilltrack-frontend.vercel.app`).

---

## Step 4: Final CORS Sync (Render)

1. Go back to Render Dashboard > `skilltrack-api` > **Environment**.
2. Update `CORS_ORIGINS` to include your exact Vercel production URL:
   ```
   CORS_ORIGINS=http://localhost:5173,https://<your-actual-app>.vercel.app
   ```
3. Save changes (Render will automatically redeploy with the updated origin).

---

## Verification Checklist

- [ ] Backend health check responds: `curl https://<render-url>/health` returns `{"status":"ok"}`.
- [ ] Database health check responds: `curl https://<render-url>/api/v1/health` returns `{"status":"ok"}`.
- [ ] Frontend loads at `https://<vercel-url>`.
- [ ] Student registration works and creates session cookies.
- [ ] Administrator login works with the account created via Render Shell.
- [ ] SPA navigation works without 404s when refreshing on deep links like `/dashboard` or `/skills`.
