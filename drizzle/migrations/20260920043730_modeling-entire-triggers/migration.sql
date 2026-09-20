-- Custom SQL migration file, put your code below! --

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
--> statement-breakpoint
CREATE TRIGGER trg_enforce_service_cap
  BEFORE INSERT ON core.services
  FOR EACH ROW
  EXECUTE FUNCTION core.fn_enforce_service_cap();
--> statement-breakpoint

-- Forward-only status transition: rejects any UPDATE that would move
-- status backward, comparing by the incident_status enum's declaration
-- order (investigating < identified < monitoring < resolved).
CREATE OR REPLACE FUNCTION core.fn_enforce_incident_status_forward_only()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.status < OLD.status THEN
    RAISE EXCEPTION 'incident % cannot move status backward from % to %', NEW.id, OLD.status, NEW.status;
  END IF;

  RETURN NEW;
END;
$$;
--> statement-breakpoint
CREATE TRIGGER trg_enforce_incident_status_forward_only
  BEFORE UPDATE OF status ON core.incidents
  FOR EACH ROW
  EXECUTE FUNCTION core.fn_enforce_incident_status_forward_only();
--> statement-breakpoint

-- A resolved incident must have at least one incident_updates row
-- recording that final state. Deferred to commit time so the status
-- and its closing incident_update can be inserted in either order.
CREATE OR REPLACE FUNCTION core.fn_enforce_incident_resolved_has_update()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.status = 'resolved' AND NOT EXISTS (
    SELECT 1 FROM core.incident_updates
    WHERE incident_id = NEW.id AND status = 'resolved'
  ) THEN
    RAISE EXCEPTION 'incident % marked resolved without a resolved incident_update', NEW.id;
  END IF;

  RETURN NEW;
END;
$$;
--> statement-breakpoint
CREATE CONSTRAINT TRIGGER trg_enforce_incident_resolved_has_update
  AFTER INSERT OR UPDATE OF status ON core.incidents
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW
  EXECUTE FUNCTION core.fn_enforce_incident_resolved_has_update();
--> statement-breakpoint

-- incident_updates is append-only: rows are never edited. Redundant
-- with the REVOKE below by design — the trigger catches a role that
-- still has the privilege; the REVOKE catches writes outside the ORM.
CREATE OR REPLACE FUNCTION core.fn_forbid_incident_update_update()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION 'incident_updates rows are append-only and cannot be updated (id %)', OLD.id;
END;
$$;
--> statement-breakpoint
CREATE TRIGGER trg_forbid_incident_update_update
  BEFORE UPDATE ON core.incident_updates
  FOR EACH ROW
  EXECUTE FUNCTION core.fn_forbid_incident_update_update();
--> statement-breakpoint
REVOKE UPDATE ON core.incident_updates FROM runner;
--> statement-breakpoint

-- incident_updates is append-only: rows are never deleted. Redundant
-- with the REVOKE below by design — the trigger catches a role that
-- still has the privilege; the REVOKE catches writes outside the ORM.
CREATE OR REPLACE FUNCTION core.fn_forbid_incident_update_delete()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION 'incident_updates rows are append-only and cannot be deleted (id %)', OLD.id;
END;
$$;
--> statement-breakpoint
CREATE TRIGGER trg_forbid_incident_update_delete
  BEFORE DELETE ON core.incident_updates
  FOR EACH ROW
  EXECUTE FUNCTION core.fn_forbid_incident_update_delete();
--> statement-breakpoint
REVOKE DELETE ON core.incident_updates FROM runner;
