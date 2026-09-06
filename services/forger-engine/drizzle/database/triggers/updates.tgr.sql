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
