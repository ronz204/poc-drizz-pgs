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

CREATE TRIGGER trg_enforce_incident_status_forward_only
  BEFORE UPDATE OF status ON core.incidents
  FOR EACH ROW
  EXECUTE FUNCTION core.fn_enforce_incident_status_forward_only();
