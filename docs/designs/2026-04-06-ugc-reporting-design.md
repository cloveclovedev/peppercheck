# UGC Reporting/Flagging Mechanism

**Date:** 2026-04-06
**Issue:** #294

## Problem

Google Play requires apps with user-generated content (UGC) to provide a mechanism for users to report inappropriate content. PepperCheck has UGC visible between users (task descriptions, evidence submissions, review comments) but currently lacks a reporting feature. This is a blocker for Google Play Store publication.

## Design

### UI: Report Entry Point

Add a `PopupMenuButton` to the existing transparent `AppBar` on `TaskDetailScreen` via the `actions` parameter of `AppScaffold.scrollable`. This adds a `⋮` icon to the top-right corner with zero visual change to the current layout (title position, font size, background all remain identical).

The menu contains a single item: "問題を報告" (Report a problem).

Both tasker and referee see this menu on the same `TaskDetailScreen`. `reporter_role` is auto-determined by comparing the current user ID with `task.tasker_id`.

Duplicate prevention: if the user has already reported this task, the menu item is disabled with "(報告済み)" suffix.

### UI: Report Bottom Sheet

Tapping "問題を報告" opens a standard Material `showModalBottomSheet` with two steps:

**Step 1 — What are you reporting?** (`content_type` selection via `RadioListTile`)

Choices depend on `reporter_role`:
- **Referee reporting**: "タスクの説明文" (`task_description`), "エビデンス" (`evidence`)
- **Tasker reporting**: "評価・コメント" (`judgement`)

**Step 2 — Why are you reporting?** (`reason` selection via `RadioListTile`)
- 不適切なコンテンツ (`inappropriate_content`)
- ハラスメント (`harassment`)
- スパム (`spam`)
- その他 (`other`)

When "その他" is selected, a `TextField` appears for free-text detail (optional).

**Submit** button at the bottom. On success, dismiss the sheet and show a `SnackBar`: "報告を送信しました".

### Backend: Schema

#### ENUMs

```sql
CREATE TYPE public.report_content_type AS ENUM (
    'task_description',
    'evidence',
    'judgement'
);

CREATE TYPE public.report_reason AS ENUM (
    'inappropriate_content',
    'harassment',
    'spam',
    'other'
);

CREATE TYPE public.report_status AS ENUM (
    'pending',
    'reviewing',
    'resolved',
    'dismissed'
);

CREATE TYPE public.reporter_role AS ENUM (
    'tasker',
    'referee'
);
```

#### Table

```sql
CREATE TABLE IF NOT EXISTS public.reports (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    reporter_id uuid NOT NULL,
    task_id uuid NOT NULL,
    reporter_role public.reporter_role NOT NULL,
    content_type public.report_content_type NOT NULL,
    content_id uuid,  -- NULL for task_description; evidence ID or judgement ID otherwise
    reason public.report_reason NOT NULL,
    detail text,  -- free-text for 'other' reason
    status public.report_status NOT NULL DEFAULT 'pending'::public.report_status,
    admin_note text,  -- admin response/action record
    resolved_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT reports_pkey PRIMARY KEY (id),
    CONSTRAINT reports_reporter_id_fkey FOREIGN KEY (reporter_id) REFERENCES auth.users(id) ON DELETE CASCADE,
    CONSTRAINT reports_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(id) ON DELETE CASCADE,
    CONSTRAINT reports_unique_per_user_task UNIQUE (reporter_id, task_id)
);

ALTER TABLE public.reports OWNER TO postgres;

CREATE INDEX idx_reports_task_id ON public.reports USING btree (task_id);
CREATE INDEX idx_reports_status ON public.reports USING btree (status);
CREATE INDEX idx_reports_created_at ON public.reports USING btree (created_at);

CREATE TRIGGER on_reports_update_set_updated_at
    BEFORE UPDATE ON public.reports
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();
```

#### RLS Policies

```sql
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

-- Users can insert their own reports
CREATE POLICY "reports: insert own" ON public.reports
    FOR INSERT
    WITH CHECK (reporter_id = (SELECT auth.uid()));

-- Users can check if they already reported a task (for duplicate prevention UI)
CREATE POLICY "reports: select own" ON public.reports
    FOR SELECT
    USING (reporter_id = (SELECT auth.uid()));
```

Admin access is handled via `service_role` key (bypasses RLS), not via user-level policies.

### Backend: Flutter Data Layer

- `ReportRepository`: calls `supabase.from('reports').insert(...)` and `supabase.from('reports').select().eq('task_id', ...).eq('reporter_id', ...)`
- `ReportController` (Riverpod AsyncNotifier): manages submit state and duplicate check
- No Edge Function needed — direct table insert via RLS is sufficient

### Admin Tooling (MVP)

SQL queries against the `reports` table for review. Future: AI-powered analysis using `content_type` + `content_id` to fetch and summarize the reported content, generating actionable reports for human reviewers.

## Scope

### In scope
- `⋮` menu on TaskDetailScreen with "問題を報告"
- Bottom sheet with content_type + reason selection
- `reports` table with ENUMs and RLS
- Flutter data/presentation layer
- Duplicate prevention (one report per user per task)
- i18n strings (ja/en)
- DB unit tests

### Out of scope
- Block user feature
- Automated moderation
- Admin notification on new report
- Admin dashboard UI
- Terms of service / privacy policy updates referencing reporting (separate issue)
