-- ============================================================================
-- EWT_API_AUDIT — application-level audit trail for the EWT API.
--
-- Records the real Entra user behind every create/update/delete performed
-- through the API (which connects as the shared ACCUTRACK account). This is
-- ADDITIVE: it does not touch any legacy table, trigger, or the EC_APP_AUDIT
-- package. The legacy *_A shadow tables continue to work unchanged.
--
-- SCOPE, AND IT IS NOT THE WHOLE PICTURE:
-- This records API writes only. The legacy Oracle Forms application writes these
-- same tables at the same time and leaves NO row here. So "who last changed this
-- record" is answerable for one of two writers, and an absent row means "not
-- changed through the API", never "not changed". Do not read this table as a
-- complete history while both systems are running.
--
-- Capturing legacy writes would need database triggers, which we may not add.
--
-- The API auto-creates these objects at startup in Dev/Test (Audit:AutoCreate=true).
-- In Prod (Audit:AutoCreate=false) a DBA runs this script once, under change control.
-- The DDL here is the SAME DDL the application issues, so there is no drift.
-- Run as the schema owner (ENVR).
-- ============================================================================

CREATE SEQUENCE EWT_API_AUDIT_SEQ START WITH 1 INCREMENT BY 1 NOCACHE;

CREATE TABLE EWT_API_AUDIT (
    AUDIT_ID       NUMBER          NOT NULL,   -- populated from EWT_API_AUDIT_SEQ.NEXTVAL
    ENTITY_NAME    VARCHAR2(128)   NOT NULL,   -- OData entity set, e.g. EC_LABLOGS
    OPERATION      VARCHAR2(10)    NOT NULL,   -- INSERT | UPDATE | DELETE
    OWNER_USER     VARCHAR2(256),             -- Entra oid (JWT claim; header fallback)
    OWNER_DISPLAY  VARCHAR2(256),             -- Entra display name
    DB_USER        VARCHAR2(128),             -- Oracle session user (cross-ref to legacy trail)
    AUDIT_TS_UTC   TIMESTAMP       NOT NULL,   -- server time in UTC
    EVENT_JSON     CLOB,                       -- the CRUD event: entity, operation, pk, values
    CONSTRAINT EWT_API_AUDIT_PK PRIMARY KEY (AUDIT_ID)
);

-- The same comment the application issues when it auto-creates the table.
COMMENT ON TABLE EWT_API_AUDIT IS 'API writes only. The legacy Forms application writes these tables concurrently and is NOT represented here, so this is not a complete change history.';

CREATE INDEX EWT_API_AUDIT_IX1 ON EWT_API_AUDIT (ENTITY_NAME, AUDIT_TS_UTC);
CREATE INDEX EWT_API_AUDIT_IX2 ON EWT_API_AUDIT (OWNER_USER, AUDIT_TS_UTC);
