-- Function + Trigger: Handle evidence timeout confirmation
CREATE OR REPLACE FUNCTION public.handle_evidence_timeout_confirmed() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = ''
    AS $$
BEGIN
    -- Only proceed if is_evidence_timeout_confirmed was changed from false to true
    -- and the judgement status is evidence_timeout
    IF NEW.is_evidence_timeout_confirmed = true
       AND OLD.is_evidence_timeout_confirmed = false
       AND NEW.status = 'evidence_timeout' THEN

        -- Previously triggered billing logic here.
        -- Billing system has been removed.
        -- Request/task closure is handled by on_judgement_confirmed_close_request trigger.
        NULL;

    END IF;

    RETURN NEW;

EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Error in handle_evidence_timeout_confirmed: %', SQLERRM;
        RETURN NEW;
END;
$$;

ALTER FUNCTION public.handle_evidence_timeout_confirmed() OWNER TO postgres;

CREATE OR REPLACE TRIGGER on_judgements_evidence_timeout_confirmed
    AFTER UPDATE OF is_evidence_timeout_confirmed ON public.judgements
    FOR EACH ROW EXECUTE FUNCTION public.handle_evidence_timeout_confirmed();

COMMENT ON TRIGGER on_judgements_evidence_timeout_confirmed ON public.judgements IS 'Trigger that fires when evidence timeout is confirmed by referee';
