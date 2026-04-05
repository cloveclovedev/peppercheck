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
