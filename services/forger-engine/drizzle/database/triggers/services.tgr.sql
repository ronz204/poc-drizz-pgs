-- Trigger: trg_services_enforce_plan_cap
-- Table: core.services | Event: BEFORE INSERT | Role: validation (plan invariant)
--
-- What it does: rejects the insert if the tenant already has as many services
-- registered as its plan's max_services allows.
--
-- Why it exists: the plan's service cap must hold regardless of caller, including
-- concurrent inserts or an application bug that skips the app-side check.

CREATE OR REPLACE FUNCTION core.fn_services_enforce_plan_cap()
RETURNS trigger AS $$
BEGIN
  IF (SELECT count(*) FROM core.services WHERE tenant_id = NEW.tenant_id)
     >= (SELECT max_services FROM auth.tenants WHERE id = NEW.tenant_id) THEN
    RAISE EXCEPTION 'tenant % has reached its plan service limit', NEW.tenant_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_services_enforce_plan_cap
  BEFORE INSERT ON core.services
  FOR EACH ROW
  EXECUTE FUNCTION core.fn_services_enforce_plan_cap();
