-- Function + Trigger: Handle evidence timeout confirmation
-- NOTE: Settlement is handled by settle_evidence_timeout() trigger on status change.
-- Request closure is handled by on_judgement_confirmed_close_request trigger.
-- This trigger is kept as a no-op for documentation purposes.
CREATE OR REPLACE FUNCTION public.handle_evidence_timeout_confirmed() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = ''
    AS $$
BEGIN
    IF NEW.is_evidence_timeout_confirmed = true
       AND OLD.is_evidence_timeout_confirmed = false
       AND NEW.status = 'evidence_timeout' THEN
        -- No-op: settlement handled by on_evidence_timeout_settle trigger.
        -- Request closure handled by on_judgement_confirmed_close_request trigger.
        NULL;
    END IF;

    RETURN NEW;
END;
$$;

ALTER FUNCTION public.handle_evidence_timeout_confirmed() OWNER TO postgres;

CREATE OR REPLACE TRIGGER on_judgements_evidence_timeout_confirmed
    AFTER UPDATE OF is_evidence_timeout_confirmed ON public.judgements
    FOR EACH ROW EXECUTE FUNCTION public.handle_evidence_timeout_confirmed();

COMMENT ON TRIGGER on_judgements_evidence_timeout_confirmed ON public.judgements IS 'No-op trigger. Settlement handled by on_evidence_timeout_settle. Request closure handled by on_judgement_confirmed_close_request.';
