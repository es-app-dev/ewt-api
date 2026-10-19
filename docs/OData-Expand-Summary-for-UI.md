# OData $expand – Summary for UI

**Audience:** UI developers / UI agent  
**API base:** `https://ewt-dev-api.energysolutions.com` (Dev) or your local/deployed base

---

## How $expand works

- The API supports **single-level and multi-level (nested) $expand** for all relationships defined in `relationships.json`.
- Each **navigation property** (e.g. `navWasteStream`, `navStatus`) is a relationship from one table to another via a foreign key.
- When you request `$expand=navWasteStream(...)`, the API:
  1. Loads the main entities (e.g. EC_TREATMENTS).
  2. Looks up the relationship by name.
  3. Fetches related rows from the target table using the FK column.
  4. Attaches the related object(s) to each entity under that nav property name.

**Important:** Nav properties are **always present** in the response:
- **Object** when a related row exists.
- **`null`** when the FK is null (no related row).  
So you can rely on the key existing; check for `null` when the relation is optional.

---

## Changes and fixes (API side)

### 1. Relationship loading

- **Before:** Only 15 relationships were loaded; many nav properties (e.g. `navWasteStream`, `navLocation`, `navStatus`) were missing → API logged "Unknown $expand: navWasteStream" and returned entities without those keys.
- **After:** Full set of **195 relationships** is loaded. The API accepts both a root array `[...]` and an object `{ "relationships": [...] }` in `relationships.json`.

### 2. Null FK handling

- **Before:** When the foreign key was null (e.g. no recipe on a treatment), the API **omitted** the nav property from the response. The UI couldn’t tell “expand not supported” from “no related record.”
- **After:** The API **always** includes the requested nav property: it’s either the related object or `null`. So e.g. `navRecipe` is present and `null` when `RECIPE_ID` is null.

### 3. Multi-level expand

- Nested `$expand` was already supported; it now works reliably with the full relationship set and null handling.
- Example: one request can return Treatment → WasteStream → Contract → Generator (3 levels).

---

## Entity sets and nav properties to use

### EC_TREATMENTS

| Nav property        | Use case                    | When null              |
|---------------------|-----------------------------|------------------------|
| navWasteStream      | Waste stream details        | No WST_STRM_ID         |
| navLocation         | Location name               | No LOCATION_ID         |
| navStatus           | Status code/description     | No PCKLST_ID_STATUS    |
| navTreatmentMethod  | Treatment method (single)    | No PCKLST_ID_TREATMENT_METHOD |
| navRecipe           | Recipe (single)             | No RECIPE_ID           |

### EC_CONTAINERS

| Nav property     | Use case              | When null        |
|------------------|-----------------------|------------------|
| navContainerType | Type code/description | No type FK       |
| navStatus        | Status                | No status FK     |
| navLocation      | Location name         | No LOCATION_ID   |
| navShipment      | Primary shipment      | No SHIPMENT_ID   |
| navOverShipment  | Over shipment         | No OVER_SHIPMENT_ID |
| navTreatment     | Treatment (TREAT_ID)  | No TREAT_ID      |

### EC_WASTE_STREAMS

| Nav property | Use case           | When null    |
|--------------|--------------------|--------------|
| navContract  | Contract + GEN_ID  | No CONTRACT_ID |

### EC_CONTRACTS (for nested expand)

| Nav property | Use case    |
|--------------|-------------|
| navGenerator | Generator (e.g. NAME) |

---

## Examples to try

Base URL: `https://ewt-dev-api.energysolutions.com/odata` (or your API base).  
Use real IDs from your environment if 25200, 12681 don’t exist.

### 1. EC_TREATMENTS list (Query tab style)

```
GET {base}/EC_TREATMENTS?$select=ID,TREATMENT_ID,RUN_NO,ARRIVED,WST_STRM_ID,LOCATION_ID&$filter=TREATMENT_ID LIKE '24%'&$orderby=ARRIVED desc&$expand=navWasteStream($select=ID,WASTEID,DESCRIPTION,CONTRACT_ID),navLocation($select=LOCATION_ID,LOCATION_NAME),navStatus($select=ID,CODE,DESCRIPTION)&$top=100
```

**Expect:** Each item in `value` has `navWasteStream`, `navLocation`, `navStatus` (object or null).

---

### 2. EC_TREATMENTS single (Treatment tab, with method/recipe)

```
GET {base}/EC_TREATMENTS?$filter=ID eq 25200&$select=ID,TREATMENT_ID,RUN_NO,WST_STRM_ID,LOCATION_ID,RECIPE_ID,PCKLST_ID_TREATMENT_METHOD&$expand=navWasteStream($select=ID,WASTEID,DESCRIPTION),navLocation($select=LOCATION_ID,LOCATION_NAME),navStatus($select=ID,CODE,DESCRIPTION),navTreatmentMethod($select=ID,CODE,DESCRIPTION),navRecipe($select=ID,RECIPE_NO,NAME)&$top=1
```

**Expect:** First item has all five nav properties; `navTreatmentMethod` and `navRecipe` may be `null` if not set.

---

### 3. EC_CONTAINERS (Containers In, by treatment)

```
GET {base}/EC_CONTAINERS?$select=ID,CONTAINER_NO,PCKLST_ID_CONTAINER_TYPE,SHIPMENT_ID,OVER_SHIPMENT_ID,TREAT_ID,LOCATION_ID,PCKLST_ID_STATUS&$filter=TREAT_ID eq 25200 or SEC_TREAT_ID eq 25200&$orderby=CONTAINER_NO&$expand=navContainerType($select=ID,CODE,DESCRIPTION),navStatus($select=ID,CODE,DESCRIPTION),navLocation($select=LOCATION_ID,LOCATION_NAME),navShipment($select=ID,SEARCH_NO,BATES_NO,ARRIVED),navOverShipment($select=ID,SEARCH_NO,BATES_NO,ARRIVED),navTreatment($select=ID,TREATMENT_ID,RUN_NO,RUN_FINAL)&$top=100
```

**Expect:** Each container has all six nav properties; `navShipment` and `navOverShipment` are `null` when not shipped.

---

### 4. EC_CONTAINERS (Containers Out – subset)

```
GET {base}/EC_CONTAINERS?$select=ID,CONTAINER_NO,PCKLST_ID_CONTAINER_TYPE,LOCATION_ID,PCKLST_ID_STATUS&$filter=SHIPMENT_ID eq null and OVER_SHIPMENT_ID eq null and TREAT_ID eq 25200&$orderby=CONTAINER_NO&$expand=navContainerType($select=ID,CODE,DESCRIPTION),navStatus($select=ID,CODE,DESCRIPTION),navLocation($select=LOCATION_ID,LOCATION_NAME)&$top=100
```

**Expect:** Each item has `navContainerType`, `navStatus`, `navLocation`.

---

### 5. EC_WASTE_STREAMS (contract for generator chain)

```
GET {base}/EC_WASTE_STREAMS?$filter=ID eq 12681&$select=ID,CONTRACT_ID&$expand=navContract($select=ID,CONTRACT_NO,GEN_ID)&$top=1
```

**Expect:** First item has `navContract` with `ID`, `CONTRACT_NO`, `GEN_ID`. Use `GEN_ID` to call EC_GENERATORS for NAME, or use multi-level expand below.

---

### 6. Multi-level: Treatment → WasteStream → Contract → Generator (one request)

```
GET {base}/EC_TREATMENTS?$filter=TREATMENT_ID LIKE '24%'&$select=ID,TREATMENT_ID,WST_STRM_ID&$expand=navWasteStream($select=ID,WASTEID,CONTRACT_ID;$expand=navContract($select=ID,CONTRACT_NO,GEN_ID;$expand=navGenerator($select=ID,NAME)))&$top=5
```

**Expect:** Each treatment has `navWasteStream`; inside it, `navContract`; inside that, `navGenerator` with `NAME`. Semicolons (`;`) separate options inside parentheses.

---

### 7. Multi-level: WasteStream → Contract → Generator (generator name in one call)

```
GET {base}/EC_WASTE_STREAMS?$filter=ID eq 12681&$select=ID,WASTEID,CONTRACT_ID&$expand=navContract($select=ID,CONTRACT_NO,GEN_ID;$expand=navGenerator($select=ID,NAME))&$top=1
```

**Expect:** First item has `navContract.navGenerator.NAME` (generator name without a separate EC_GENERATORS request).

---

## Syntax notes for the UI

- **Multiple expands:** Comma-separated: `$expand=navWasteStream(...),navLocation(...),navStatus(...)`.
- **Options inside expand:** Use parentheses and semicolons: `navWasteStream($select=ID,WASTEID;$expand=navContract(...))`.
- **Nested expand:** Same pattern recursively; the API resolves relationships by name per table.

---

## What the UI can do now

1. **Rely on $expand** for EC_TREATMENTS, EC_CONTAINERS, and EC_WASTE_STREAMS for the nav properties listed above. No need for fallback lookups for these endpoints when the API is the Dev (or updated) deployment.
2. **Treat missing relation as `null`:** If a nav property is present and `null`, the FK is null. If the property is absent, the API may be an old build without the fix — consider a fallback only in that case.
3. **Use multi-level expand** to get generator name (or other chains) in one request and reduce round-trips.

---

## Verification

- **API repo:** `ewt-ui/docs/api-expand-test-requests.md` has the same 5 single-level requests and expected responses.
- **API repo:** `scripts/Verify-ODataExpand.ps1` runs those 5 tests against a given base URL (e.g. Dev).  
  Example: `.\scripts\Verify-ODataExpand.ps1 -BaseUrl "https://ewt-dev-api.energysolutions.com/odata"`

All listed examples have been run successfully against `https://ewt-dev-api.energysolutions.com`.
