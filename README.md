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
5. To deploy to your Supabase project:
   - Log in and link your project:
     ```sh
     supabase login
     supabase link --project-ref <your-ref>
     ```
   - Set Edge Functions environment variables from `supabase/functions/.env`:
     ```sh
     supabase secrets set --env-file supabase/functions/.env
     ```
   - Deploy required Edge Functions (example):
     ```sh
     supabase functions deploy generate-upload-url
     ```
   - Apply database changes as needed:
     ```sh
     supabase db push
     ```
   You can also rely on the supplied GitHub Actions for CI/CD if preferred.

## Edge Function formatting & linting

Supabase Edge Functions are written in TypeScript (Deno). A minimal toolchain is provided to
keep them consistent locally and inside pull requests:

- `.pre-commit-config.yaml` runs `deno fmt --check` and `deno lint` against every
  `supabase/functions/**` file. Install it once with `pip install pre-commit && pre-commit install`,
  then the checks run automatically before each commit or manually via `pre-commit run --all-files`.
- `supabase/deno.jsonc` defines the shared formatting/linting scope so every function follows the
  same line width, quote style, and lint rule-set.
- `.vscode/settings.json` enables the official Deno extension only for `supabase/functions`, turns on
  format-on-save, and applies the same config while editing so you see formatter/lint feedback in the
  editor.

Ensure you have Deno installed locally (<https://deno.com/manual/getting_started/installation>) so
that both pre-commit hooks and the VS Code extension can execute.

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
