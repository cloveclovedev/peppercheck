# PepperCheck Web App

## Setup

1. Copy `.env.template` to `.env.local` and fill in your Supabase URL and Anon Key.
   ```bash
   cp .env.template .env.local
   ```
2. Install dependencies:
   ```bash
   npm install
   ```
3. Run development server:
   ```bash
   npm run dev
   ```

## Pages

- `/`: Home Page
- `/pricing`: Pricing Plans (Fetching from Supabase)
- `/dashboard`: User Dashboard (Requires Supabase Auth)
