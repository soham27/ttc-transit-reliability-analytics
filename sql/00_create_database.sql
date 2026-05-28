-- sql/00_create_database.sql
-- TTC Transit Reliability Analytics — Stage 3
--
-- Run this ONCE, in pgAdmin's Query Tool, while connected to the default
-- `postgres` maintenance database. After it runs, switch your pgAdmin
-- connection to `ttc_reliability` and run `sql/01_create_schema.sql` next.
--
-- You cannot create a database from inside a transaction, so this file
-- contains only the single CREATE DATABASE statement.

CREATE DATABASE ttc_reliability
    WITH
    ENCODING = 'UTF8'
    TEMPLATE = template0;

COMMENT ON DATABASE ttc_reliability IS
    'TTC Transit Reliability Analytics — fact and dimension tables for the 2022+ delay-event analysis.';
