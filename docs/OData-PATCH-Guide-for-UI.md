# OData PATCH (and POST) – Guide for UI

**Audience:** UI developers / UI agent  
**API base:** `https://ewt-dev-api.energysolutions.com` (Dev) or your deployed base

---

## How PATCH works

PATCH partially updates a single entity. You send the **primary key** plus only the **fields you want to change**. Fields you omit are left untouched.

```
PATCH /odata/{EntitySet}
Content-Type: application/json

{
  "ID": 25200,
  "NOTE": "Updated note text",
  "APPROVAL_DATE": "2026-02-14T00:00:00"
}
```

### Request rules

1. **Primary key is required in the body.** The API extracts it from the JSON body (not the URL). For most tables this is `ID`. For compound keys, include all key columns.
2. **Only send fields you want to change.** Omitted fields are not touched. This is a true partial update.
3. **Column names are case-insensitive.** `"note"`, `"NOTE"`, and `"Note"` all work: they're normalized to uppercase internally.
4. **Primary key fields are excluded from the SET clause.** They're used only in the WHERE clause. You can't change a PK via PATCH.

### Response

| Status | Meaning |
|--------|---------|
| **204 No Content** | Success, entity was updated |
| **400 Bad Request** | Missing PK, empty body, or no updateable fields |
| **404 Not Found** | Entity with that PK doesn't exist, or table doesn't exist |
| **500 Internal Server Error** | Oracle error (details in response body) |

PATCH returns **no body** on success (204). If you need the updated entity, issue a GET after the PATCH.

---

## Data type handling

The API automatically converts JSON types to Oracle types. Here's what to send for each column type:

### Strings (VARCHAR2, CHAR, CLOB)

```json
{ "ID": 25200, "NOTE": "Some text value" }
```

### Numbers (NUMBER, INTEGER, FLOAT)

```json
{ "ID": 25200, "ANUMBER": 42, "WEIGHT": 125.5 }
```

Send as JSON numbers (no quotes). Both integers and decimals work.

### Dates (DATE, TIMESTAMP)

```json
{ "ID": 25200, "APPROVAL_DATE": "2026-02-14T00:00:00" }
```

Send as **ISO 8601 string** with the `T` separator. The API's `ParseStringValue()` detects this format and converts it to a .NET `DateTime` before binding to Oracle.

Valid date formats:
- `"2026-02-14T00:00:00"`: date and time
- `"2026-02-14T15:30:00"`: date with specific time
- `"2026-02-14"`: date only (10+ chars with dashes)

**Do NOT send dates as plain strings without dashes/T** (e.g. `"20260214"`); they won't be parsed as dates.

### Null values (clearing a field)

```json
{ "ID": 25200, "APPROVAL_DATE": null, "NOTE": null }
```

Send `null` as the JSON value. The API sets the Oracle column to NULL. It looks up the column type from metadata to set the correct `OracleDbType` on the parameter, so nulls work for all column types (strings, numbers, dates).

### Booleans

Oracle doesn't have a native boolean type. If a column stores 0/1 or Y/N, send the appropriate number or string:

```json
{ "ID": 123, "VTD_FLAG": "Y" }
```

---

## POST (create)

POST creates a new entity. Send all required columns in the body.

```
POST /odata/{EntitySet}
Content-Type: application/json

{
  "TREATMENT_ID": "260214A",
  "RUN_NO": 1,
  "WST_STRM_ID": 12681,
  "LOCATION_ID": 100
}
```

### Response

| Status | Meaning |
|--------|---------|
| **201 Created** | Success, returns the created entity |
| **400 Bad Request** | Empty body |
| **404 Not Found** | Table doesn't exist |
| **500 Internal Server Error** | Oracle constraint violation, missing required column, etc. |

**Note:** For the 80 tables listed by `GET /admin/sequences`, leave the primary key out of
the body and the server allocates it, returning the created entity with its key. Send the
key explicitly and it is used exactly as given. For every other table the API still passes
exactly what you send, so the key has to come from you or from a trigger. `/admin/schema/{table}`
reports `generatedKey` when the server will allocate one.

---

## Examples

### PATCH a treatment note

```
PATCH /odata/EC_TREATMENTS
Content-Type: application/json

{
  "ID": 25200,
  "NOTE": "Repack completed, awaiting approval"
}
```

### PATCH to clear a date

```
PATCH /odata/EC_TREATMENTS
Content-Type: application/json

{
  "ID": 25200,
  "APPROVAL_DATE": null
}
```

### PATCH to set a date

```
PATCH /odata/EC_TREATMENTS
Content-Type: application/json

{
  "ID": 25200,
  "APPROVAL_DATE": "2026-02-14T00:00:00"
}
```

### PATCH multiple fields at once

```
PATCH /odata/EC_TREATMENTS
Content-Type: application/json

{
  "ID": 25200,
  "NOTE": "Updated",
  "APPROVAL_DATE": "2026-02-14T00:00:00",
  "PCKLST_ID_STATUS": 4302,
  "PCKLST_ID_TREATMENT_METHOD": 5100
}
```

### PATCH a container location

```
PATCH /odata/EC_CONTAINERS
Content-Type: application/json

{
  "ID": 98765,
  "LOCATION_ID": 200
}
```

### POST a new treatment

```
POST /odata/EC_TREATMENTS
Content-Type: application/json

{
  "TREATMENT_ID": "260214A",
  "RUN_NO": 1,
  "WST_STRM_ID": 12681,
  "LOCATION_ID": 100,
  "PCKLST_ID_STATUS": 4301
}
```

---

## Common pitfalls

### 1. Primary key must be in the body, not the URL

```
// WRONG: PK in URL path (this is a GET-by-key, not PATCH)
PATCH /odata/EC_TREATMENTS(25200)

// RIGHT: PK in body
PATCH /odata/EC_TREATMENTS
{ "ID": 25200, "NOTE": "Updated" }
```

### 2. Don't send PK-only bodies

If you send only the primary key with no other fields, you get 400:

```json
{ "ID": 25200 }
// → 400: "No fields to update"
```

### 3. Date strings need ISO 8601 format

```json
// WRONG: won't be parsed as a date
{ "ID": 25200, "APPROVAL_DATE": "02/14/2026" }

// RIGHT
{ "ID": 25200, "APPROVAL_DATE": "2026-02-14T00:00:00" }
```

### 4. String values that look like numbers

JSON numbers are sent as numbers to Oracle. If a VARCHAR2 column needs a numeric-looking value, send it as a string:

```json
{ "ID": 25200, "CODE": "11e2" }
```

The `"11e2"` stays as the string `11e2`, not the number 1100.

### 5. Use GET after PATCH to confirm

PATCH returns 204 (no body). To see the updated entity:

```
GET /odata/EC_TREATMENTS?$filter=ID eq 25200&$select=ID,NOTE,APPROVAL_DATE
```

---

## Internal flow (for reference)

1. **Receive body** → `Dictionary<string, object?>` from JSON
2. **Convert values** → `ConvertJsonElement()` converts `JsonElement` objects to .NET types:
   - `JsonValueKind.String` → string (or `DateTime` if ISO 8601 detected by `ParseStringValue()`)
   - `JsonValueKind.Number` → `long` if integer, otherwise `decimal`
   - `JsonValueKind.Null` → `null`
3. **Normalize keys** → column names uppercased
4. **Extract PK** → primary key columns separated into WHERE clause
5. **Build UPDATE** → `UPDATE "OWNER"."TABLE" SET "COL1" = :set0, "COL2" = :set1 WHERE "ID" = :key0`
6. **Bind parameters** → values bound with `OracleParameter`; null values get explicit `OracleDbType` from metadata
7. **Execute** → returns row count; 0 means entity not found (404)
