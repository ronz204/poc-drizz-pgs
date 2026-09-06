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
