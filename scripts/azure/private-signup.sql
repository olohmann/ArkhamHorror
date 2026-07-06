-- Invite-only accounts
-- ----------------------------------------------------------------------------
-- Disables public self-registration. The app's POST /api/v1/register handler
-- simply INSERTs into users, so a BEFORE INSERT trigger that blocks inserts
-- (unless the connection explicitly opts in) turns the instance invite-only.
--
-- The admin creates accounts by opening a connection with the opt-in flag set:
--   PGOPTIONS="-c app.allow_register=on" psql ... -c "INSERT INTO users ..."
-- (see scripts/azure/create-user.sh). The app never sets this flag, so
-- self-registration is rejected.
--
-- Idempotent: safe to run on every deploy.

CREATE OR REPLACE FUNCTION block_public_registration()
  RETURNS trigger
  LANGUAGE plpgsql
AS $$
BEGIN
  IF coalesce(current_setting('app.allow_register', true), 'off') <> 'on' THEN
    RAISE EXCEPTION 'Public registration is disabled on this instance'
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_block_public_registration ON users;
CREATE TRIGGER trg_block_public_registration
  BEFORE INSERT ON users
  FOR EACH ROW
  EXECUTE FUNCTION block_public_registration();
