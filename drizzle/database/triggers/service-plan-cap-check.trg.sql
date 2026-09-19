-- Enforces tenants.max_services at the database level: a concurrent
-- insert or application bug can't silently overrun the plan cap. Locks
-- the tenant row so two concurrent inserts can't both pass the count.
CREATE OR REPLACE FUNCTION core.fn_enforce_service_cap()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  max_allowed integer;
  current_count integer;
BEGIN
  SELECT max_services INTO max_allowed FROM core.tenants WHERE id = NEW.tenant_id FOR UPDATE;
  SELECT count(*) INTO current_count FROM core.services WHERE tenant_id = NEW.tenant_id;

  IF current_count >= max_allowed THEN
    RAISE EXCEPTION 'tenant % has reached its service cap of %', NEW.tenant_id, max_allowed;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_enforce_service_cap
  BEFORE INSERT ON core.services
  FOR EACH ROW
  EXECUTE FUNCTION core.fn_enforce_service_cap();
