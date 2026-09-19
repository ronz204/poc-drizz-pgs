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

CREATE CONSTRAINT TRIGGER trg_enforce_incident_resolved_has_update
  AFTER INSERT OR UPDATE OF status ON core.incidents
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW
  EXECUTE FUNCTION core.fn_enforce_incident_resolved_has_update();
