# peppercheck

## Getting Started (Android)

1. Copy `android/local.properties.example` to `android/local.properties` and fill in the required values:
   - `SUPABASE_URL` / `SUPABASE_ANON_KEY`
   - `GATEWAY_URL`
   - `WEB_GOOGLE_CLIENT_ID`
   - (Optional) set `*_DEBUG` variants if you run a local Supabase instance.
2. Download your Firebase configuration from the Firebase Console and place it at `android/app/google-services.json`.
3. Open the project in Android Studio (or run `./gradlew assembleDebug`) to verify the build.

These configuration files are intentionally excluded from version control, so each developer must provide their own values before compiling the app.

## Supabase Setup

1. Install the Supabase CLI (<https://supabase.com/docs/guides/cli>). The project expects at least v1.191.4 or newer.
2. Copy `supabase/.env.example` to `supabase/.env` and fill in provider credentials such as `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` if you intend to enable those auth providers.
3. Copy `supabase/functions/.env.example` to `supabase/functions/.env` and supply your Cloudflare R2 credentials (`CLOUDFLARE_ACCOUNT_ID`, `R2_BUCKET_NAME`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`). These are required for the `generate-upload-url` Edge Function.
4. For local development, run `supabase start` from the repository root to launch a local Postgres + Supabase stack, then point `SUPABASE_URL_DEBUG` / `GATEWAY_URL_DEBUG` in `local.properties` at the local endpoint (`http://10.0.2.2:54321` for Android emulator).
5. To deploy to your Supabase project, log in with `supabase login`, link the project (`supabase link --project-ref <your-ref>`), and use the supplied GitHub Actions or `supabase db push` / `supabase functions deploy` manually.

## Cloudflare Gateway Worker

The repository includes `cloudflare/gateway-proxy`, a Cloudflare Worker that proxies API traffic to Supabase.

1. `cd cloudflare/gateway-proxy` and run `npm install` (or `npm ci`).
2. Use Wrangler to provide the Supabase project reference:
   ```sh
   npx wrangler secret put SUPABASE_PROJECT_ID
   ```
3. For local testing, run `npx wrangler dev` (the worker listens on <http://127.0.0.1:8787>). Point `GATEWAY_URL_DEBUG` at this endpoint if you prefer routing through the worker during Android debugging.
4. Deploy with `npx wrangler deploy` once you have configured your Cloudflare account.

The worker does not store secrets in the repository; all credentials must be supplied via Wrangler secrets or Cloudflare dashboard settings before running it.
