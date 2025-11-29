-- Prevents task creation if the tasker has unpaid billing jobs at/over retry limit.
CREATE OR REPLACE FUNCTION public.block_task_creation_if_unpaid()
RETURNS trigger
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = ''
AS $$
DECLARE
  v_is_billing_action_required boolean;
BEGIN
  v_is_billing_action_required := public.is_billing_action_required(NEW.tasker_id);

  IF v_is_billing_action_required THEN
    RAISE EXCEPTION 'You have an unpaid task. Please update your payment method and retry the payment.';
  END IF;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.block_task_creation_if_unpaid()
  IS 'Blocks new task creation for taskers who have failed billing jobs at/over retry limit.';
