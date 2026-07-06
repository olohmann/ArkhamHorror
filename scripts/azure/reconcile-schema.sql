-- Azure schema reconcile
-- ----------------------------------------------------------------------------
-- These objects exist in the repo's setup.sql (the canonical baseline dump) but
-- have NO corresponding file in migrations/deploy/. The Azure deploy bootstraps
-- a fresh database with ARKHAM_FORCE_MIGRATIONS=1 (migrations only, no
-- setup.sql), so without this step the live schema would be missing:
--   * users.admin        (required by the Persistent User entity -> breaks
--                          registration/login)
--   * notifications table (backs GET /api/v1/notifications)
--
-- Applied idempotently after migrate.sh. Safe to run repeatedly.

ALTER TABLE users ADD COLUMN IF NOT EXISTS admin boolean NOT NULL DEFAULT false;

CREATE TABLE IF NOT EXISTS notifications (
    id integer NOT NULL,
    body text,
    created_at timestamp without time zone
);

CREATE SEQUENCE IF NOT EXISTS notifications_id_seq
    AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
ALTER SEQUENCE notifications_id_seq OWNED BY notifications.id;
ALTER TABLE ONLY notifications
    ALTER COLUMN id SET DEFAULT nextval('notifications_id_seq'::regclass);

DO $$ BEGIN
  ALTER TABLE ONLY notifications ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);
EXCEPTION WHEN others THEN NULL; END $$;
