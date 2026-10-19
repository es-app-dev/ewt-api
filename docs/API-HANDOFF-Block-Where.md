# Block WHERE clauses the UI cannot translate: run them as the form wrote them

**From:** the UI/spec side (`C:\essource\ewt-ui`)
**Date:** 2026-09-30
**Decision behind it:** Bruce, 30 Sep: *"Build the 87"*, sticking to legacy behaviour. A Forms block's
WHERE clause decides which rows the screen shows at all. Dropping it shows rows the legacy never shows.
**Audience:** the API side
**Builds on:** the dynamic OData query in `DynamicDataService`, `$filter`, and `/admin/relationships`.

## The problem

A Forms data block has a WHERE clause that Forms adds to every query of the block, and it is SQL.
The UI turns the simple ones into `$filter` (`TERMINAL_IND eq 'Y'`, and `IN (...)` lists, which the
API accepts). About 20 blocks in 15 of the 87 screens use SQL that `$filter` cannot say:

| Screen.block | The block's WHERE (abridged) | Why `$filter` cannot say it |
|---|---|---|
| AT5520.OUTSHIPMT | `shipment_nbr in (select shipment_nbr from at_shipments where to_char(shipment_dt,'RRRR') = to_char(sysdate,'RRRR') ...) and disp_site_seq_id in (select disp_site_seq_id from at_disp_site_acks)` | subqueries (a semi-join) |
| AT5521.OUTSHIPMT | `DISP_SITE_SEQ_ID = 2 and shipment_nbr in (select shipment_nbr from at_shipments where shipment_dt is not null)` | a subquery over 62,719 rows: too many keys for a two-step `in (...)` under IIS's 2,048-character limit |
| AT5510 / AT5511 | `SHIPMENT_NBR IN (SELECT SHIPMENT_NBR FROM AT_SHIPMENTS WHERE SUBSTR(SHIPMENT_TYPE_CD,1,8) <> 'TRANSFER')` | a subquery |
| AT4210 / AT4211 / AT4215 | `ALL_PARENTS_EMPTY(CNTNR_SEQ_ID)='TRUE' AND PRCTRANTYP_SEQ_ID IN (select ... like '2%')` | a PL/SQL function |
| AT3110 (2 blocks) | `NOT EXISTS (SELECT 1 FROM at_barcode_haz_waste_codes ... = :matl.matl_seq_id ...)` | a correlated subquery with the master's values |
| AT5311 / AT5316 | `labsample_seq_id in (select distinct ... from at_lab_samples, at_lab_analysis_samples, at_lab_analysis_types ...)` | a three-table subquery |
| AT5161, AT1310.COMNT, WB1000, WB2002, AT1510 | nested `IN`, `MAX(...)`, `NOT IN (select ...)`, `CONNECT BY`, a database link | as named |

We tried the relationships the API already has. `AT_OUTBOUND_SHIPMENTS → Shipments` (many-to-one on
SHIPMENT_NBR) exists, but on dev (BCTN) the filters through it fail:

    $filter=DISP_SITE_SEQ_ID eq 2 and Shipments/SHIPMENT_DT ne null          -> ORA-00904: "SHIPMENT_DT": invalid identifier
    $filter=DISP_SITE_SEQ_ID eq 2 and Shipments/any(s:s/SHIPMENT_DT ne null)  -> ORA-00936: missing expression

Fixing those would cover the plain semi-joins (AT5521, AT5510, AT5511) but not the functions, the
correlated subqueries, CONNECT BY or the database link.

## What we ask for: named block WHEREs, held by the API

A registry on the server of the WHERE clauses the forms use, each under a name, each reviewed. A GET
names one, and the API appends its text to the query's WHERE with AND, exactly as Forms does:

    GET /odata/AT_OUTBOUND_SHIPMENTS?db=BCTN&where=AT5521.OUTSHIPMT&$filter=SHIPMENT_NBR eq '000150'

    SELECT ... FROM AT_OUTBOUND_SHIPMENTS
     WHERE (<the registry's text for AT5521.OUTSHIPMT>) AND (<the translated $filter>)

- **The text never comes from the client.** The request carries a name; an unknown name is 400. So this
  is no more open than a view, and no SQL travels in a URL.
- **Binds.** Some WHEREs read the screen: `:MATL.CNTNR_SEQ_ID` (the master's current record),
  `:AT$CTRL.INCINERATOR_ID`. The registry lists each bind by name; the client sends values as query
  parameters (`&bind.MATL.CNTNR_SEQ_ID=4211`); the API binds them as Oracle bind variables, never
  concatenated. A missing bind is 400.
- **Per entity set.** A name is valid only with the entity set it was written for.
- **$count, $top, $orderby, $select** work as they do now.
- **Writes are unchanged.** PATCH / DELETE / `$batch` address rows by key as today; the WHERE only
  decides what a query shows.

The UI side will generate the registry (one entry per block WHERE the UI cannot translate, with its
binds and the form it came from) for you to review and place, the same way `relationships.json` is.

## Until then

Those screens are not built. Everything else in them waits on this one thing, so they are listed in
`ewt-ui/BUILD-87.md` as waiting on the API.

## Also sent to you today, nothing needed from the API

`ewt-api/OurPackages/EWT_UI.sql` now carries 91 list-of-values procedures (generated section between
markers), deployed by the next API restart. Each opens its form's own record-group query as a REF
CURSOR, which `/odata/proc` already returns as rows. That covers the lists `$filter` cannot say (joins,
UNIONs, subqueries) without any API change. They are read-only: `OPEN ... FOR` a SELECT, values bound.
