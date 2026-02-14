-- Function + Trigger: Close referee request when judgement is confirmed
CREATE OR REPLACE FUNCTION public.close_referee_request_on_confirmed() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = ''
    AS $$
BEGIN
    UPDATE public.task_referee_requests
    SET status = 'closed'::public.referee_request_status
    WHERE id = NEW.id;

    RETURN NEW;
END;
$$;

ALTER FUNCTION public.close_referee_request_on_confirmed() OWNER TO postgres;

CREATE OR REPLACE TRIGGER on_judgement_confirmed_close_request
    AFTER UPDATE ON public.judgements
    FOR EACH ROW
    WHEN (
        (NEW.is_confirmed = true AND OLD.is_confirmed = false)
        OR (NEW.is_evidence_timeout_confirmed = true AND OLD.is_evidence_timeout_confirmed = false)
    )
    EXECUTE FUNCTION public.close_referee_request_on_confirmed();
