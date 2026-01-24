-- Function to send notifications via Edge Function
-- Located in supabase/schemas/notification/functions/001_notify_matching.sql

CREATE OR REPLACE FUNCTION public.notify_event(
    p_user_id uuid,
    p_template_key text,
    p_template_args text[] DEFAULT NULL,
    p_data jsonb DEFAULT '{}'::jsonb
) RETURNS void
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = ''
    AS $$
DECLARE
    v_url text;
    v_service_role_key text;
    v_headers jsonb;
    v_payload jsonb;
BEGIN
    -- Get secrets
    SELECT decrypted_secret
    INTO v_url
    FROM vault.decrypted_secrets
    WHERE name = 'send_notification_url';

    SELECT decrypted_secret
    INTO v_service_role_key
    FROM vault.decrypted_secrets
    WHERE name = 'service_role_key';

    IF v_url IS NULL OR v_service_role_key IS NULL THEN
        -- Log warning but don't fail transaction
        RAISE WARNING 'notify_event: missing secret (url:%, service_role_key found:%)', v_url, v_service_role_key IS NOT NULL;
        RETURN;
    END IF;

    v_headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || v_service_role_key,
        'apikey', v_service_role_key
    );

    v_payload := jsonb_build_object(
        'user_ids', jsonb_build_array(p_user_id),
        'notification', jsonb_build_object(
            'title_loc_key', p_template_key || '_title',
            'title_loc_args', COALESCE(p_template_args, ARRAY[]::text[]),
            'body_loc_key', p_template_key || '_body',
            'body_loc_args', COALESCE(p_template_args, ARRAY[]::text[]),
            'data', p_data
        )
    );

    -- Send via pg_net
    PERFORM net.http_post(
        url => v_url,
        body => v_payload,
        headers => v_headers,
        timeout_milliseconds => 5000
    );

EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'notify_event failed: %', SQLERRM;
END;
$$;

ALTER FUNCTION public.notify_event(uuid, text, text[], jsonb) OWNER TO postgres;

COMMENT ON FUNCTION public.notify_event(uuid, text, text[], jsonb) IS 'Helper function to send push notifications by calling the send-notification Edge Function via pg_net. It constructs a localized payload structure.';
