INSERT INTO public.matching_config (key, value, description)
VALUES
    ('min_due_date_interval_hours', '1'::jsonb, 'Minimum hours between now and due date for open tasks')
ON CONFLICT (key) DO UPDATE
SET value = EXCLUDED.value,
    description = EXCLUDED.description,
    updated_at = now();
