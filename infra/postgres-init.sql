-- Runs once when the postgres volume is first initialized.
-- Keycloak needs its schema to exist before it starts (it won't create it).
CREATE SCHEMA IF NOT EXISTS keycloak;
