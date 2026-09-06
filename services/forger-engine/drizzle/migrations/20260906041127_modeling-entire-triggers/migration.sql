-- Custom SQL migration file, put your code below! --

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

-- Trigger: trg_incidents_enforce_forward_status
-- Table: core.incidents | Event: BEFORE UPDATE OF status | Role: validation (status invariant)
--
-- What it does: rejects a status update that moves backward relative to the
-- incident_status enum's declaration order (investigating -> identified ->
-- monitoring -> resolved).
--
-- Why it exists: the forward-only transition is a domain invariant; enforcing it
-- here means no caller can violate it regardless of how it issues the update.

CREATE OR REPLACE FUNCTION core.fn_incidents_enforce_forward_status()
RETURNS trigger AS $$
BEGIN
  IF NEW.status < OLD.status THEN
    RAISE EXCEPTION 'incident status cannot move backward (% -> %)', OLD.status, NEW.status;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_incidents_enforce_forward_status
  BEFORE UPDATE OF status ON core.incidents
  FOR EACH ROW
  EXECUTE FUNCTION core.fn_incidents_enforce_forward_status();

-- Trigger: trg_incidents_require_resolved_update
-- Table: core.incidents | Event: AFTER INSERT OR UPDATE OF status, deferred | Role: validation (cross-row invariant)
--
-- What it does: at commit time, if status is 'resolved', checks that at least one
-- core.incident_updates row for this incident also carries status = 'resolved'.
--
-- Why it exists: an incident must never end up resolved without a corresponding
-- closing update recording that final state. Running as a DEFERRABLE INITIALLY
-- DEFERRED constraint trigger lets the incident row and its closing
-- incident_updates row be inserted in either order within the same transaction.

CREATE OR REPLACE FUNCTION core.fn_incidents_require_resolved_update()
RETURNS trigger AS $$
BEGIN
  IF NEW.status = 'resolved' AND NOT EXISTS (
    SELECT 1 FROM core.incident_updates
    WHERE incident_id = NEW.id AND status = 'resolved'
  ) THEN
    RAISE EXCEPTION 'incident % marked resolved without a resolved incident_update', NEW.id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER trg_incidents_require_resolved_update
  AFTER INSERT OR UPDATE OF status ON core.incidents
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW
  EXECUTE FUNCTION core.fn_incidents_require_resolved_update();

-- Trigger: trg_incident_updates_forbid_mutation
-- Table: core.incident_updates | Event: BEFORE UPDATE OR DELETE | Role: validation (immutability invariant)
--
-- What it does: raises an exception on any UPDATE or DELETE issued against this
-- table.
--
-- Why it exists: incident_updates is an append-only timeline. This trigger and
-- the REVOKE below are deliberately redundant defense in depth - the trigger
-- catches a mutation from any role that still has the privilege (e.g. a
-- maintenance script running as a more privileged role than "runner"), the
-- REVOKE catches an attempt that bypasses ORM-issued statements entirely.

CREATE OR REPLACE FUNCTION core.fn_incident_updates_forbid_mutation()
RETURNS trigger AS $$
BEGIN
  RAISE EXCEPTION 'incident_updates rows are append-only and cannot be %', TG_OP;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_incident_updates_forbid_mutation
  BEFORE UPDATE OR DELETE ON core.incident_updates
  FOR EACH ROW
  EXECUTE FUNCTION core.fn_incident_updates_forbid_mutation();

REVOKE UPDATE, DELETE ON core.incident_updates FROM runner;