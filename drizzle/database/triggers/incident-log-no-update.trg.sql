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

CREATE TRIGGER trg_forbid_incident_update_update
  BEFORE UPDATE ON core.incident_updates
  FOR EACH ROW
  EXECUTE FUNCTION core.fn_forbid_incident_update_update();

REVOKE UPDATE ON core.incident_updates FROM runner;
