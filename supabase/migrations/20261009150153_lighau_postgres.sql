-- Private application data. This migration is applied by the schema owner,
-- while the runtime uses lighau_backend with no DDL or RLS-bypass privileges.
DO $$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname='lighau_backend') THEN
    CREATE ROLE lighau_backend LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
  END IF;
END $$;
CREATE SCHEMA lighau;
REVOKE ALL ON SCHEMA lighau FROM PUBLIC;
GRANT USAGE ON SCHEMA lighau TO lighau_backend;

CREATE TABLE lighau.settings (key text PRIMARY KEY, value jsonb NOT NULL);
CREATE TABLE lighau.facilities (
  position bigserial UNIQUE NOT NULL,
  id text PRIMARY KEY,
  name text NOT NULL CHECK (length(btrim(name)) BETWEEN 1 AND 200),
  version integer NOT NULL CHECK (version > 0),
  record jsonb NOT NULL CHECK (jsonb_typeof(record)='object'),
  CHECK (record ?& ARRAY['id','name','version']),
  CHECK (record->>'id'=id AND record->>'name'=name AND (record->>'version')::integer=version),
  CHECK ((record->>'latitude' IS NULL) = (record->>'longitude' IS NULL)),
  CHECK (record->>'latitude' IS NULL OR (record->>'latitude')::double precision BETWEEN -90 AND 90),
  CHECK (record->>'longitude' IS NULL OR (record->>'longitude')::double precision BETWEEN -180 AND 180),
  CHECK (record->>'floors' IS NULL OR (record->>'floors')::integer BETWEEN 1 AND 200)
);
CREATE UNIQUE INDEX facilities_name_unique ON lighau.facilities (lower(name));
CREATE TABLE lighau.accounts (
  username text PRIMARY KEY,
  hash text NOT NULL CHECK (hash ~ '^[a-f0-9]{32}:[a-f0-9]{128}$'), role text NOT NULL,
  disabled boolean NOT NULL DEFAULT false
);
CREATE TABLE lighau.sessions (
  hash text PRIMARY KEY CHECK (hash ~ '^[a-f0-9]{64}$'), username text NOT NULL REFERENCES lighau.accounts(username),
  expires bigint NOT NULL
);
CREATE INDEX session_expiry ON lighau.sessions(expires);
CREATE TABLE lighau.counters (key text PRIMARY KEY, used integer NOT NULL CHECK (used>=0), resets bigint NOT NULL);
CREATE INDEX counter_expiry ON lighau.counters(resets);
CREATE TABLE lighau.leases (id text PRIMARY KEY, expires bigint NOT NULL);
CREATE INDEX lease_expiry ON lighau.leases(expires);
CREATE TABLE lighau.audit (
  id bigserial PRIMARY KEY, at timestamptz NOT NULL, actor text NOT NULL,
  operation text NOT NULL, facility_id text, before_json jsonb, after_json jsonb
);
CREATE TABLE lighau.provider_events (
  id bigserial PRIMARY KEY, model text NOT NULL, at bigint NOT NULL,
  input_tokens integer NOT NULL DEFAULT 0 CHECK (input_tokens>=0)
);
CREATE INDEX provider_event_time ON lighau.provider_events(model,at);

GRANT SELECT,INSERT,UPDATE,DELETE ON lighau.settings,lighau.facilities,lighau.accounts,
  lighau.sessions,lighau.counters,lighau.leases,lighau.provider_events TO lighau_backend;
GRANT SELECT,INSERT ON lighau.audit TO lighau_backend;
GRANT USAGE,SELECT ON ALL SEQUENCES IN SCHEMA lighau TO lighau_backend;
ALTER DEFAULT PRIVILEGES IN SCHEMA lighau REVOKE ALL ON TABLES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA lighau REVOKE ALL ON SEQUENCES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA lighau REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;

DO $$ DECLARE target text; browser_role text; BEGIN
  FOREACH browser_role IN ARRAY ARRAY['anon','authenticated','service_role'] LOOP
    IF EXISTS (SELECT FROM pg_roles WHERE rolname=browser_role) THEN
      EXECUTE format('REVOKE ALL ON SCHEMA lighau FROM %I', browser_role);
      EXECUTE format('REVOKE ALL ON ALL TABLES IN SCHEMA lighau FROM %I', browser_role);
      EXECUTE format('REVOKE ALL ON ALL SEQUENCES IN SCHEMA lighau FROM %I', browser_role);
    END IF;
  END LOOP;
  FOREACH target IN ARRAY ARRAY['settings','facilities','accounts','sessions','counters','leases','provider_events'] LOOP
    EXECUTE format('ALTER TABLE lighau.%I ENABLE ROW LEVEL SECURITY', target);
    EXECUTE format('CREATE POLICY backend_access ON lighau.%I TO lighau_backend USING (true) WITH CHECK (true)', target);
  END LOOP;
END $$;
ALTER TABLE lighau.audit ENABLE ROW LEVEL SECURITY;
CREATE POLICY backend_audit_read ON lighau.audit FOR SELECT TO lighau_backend USING (true);
CREATE POLICY backend_audit_insert ON lighau.audit FOR INSERT TO lighau_backend WITH CHECK (true);
INSERT INTO lighau.settings VALUES ('schema_version','1'::jsonb);
