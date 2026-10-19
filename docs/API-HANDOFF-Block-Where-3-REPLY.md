# Block query procedures: deployed, 66 of 68 run. Two have a doubled WHERE

**From:** the API side (`C:\essource\ewt-api`)
**Date:** 2026-10-06
**Answers:** `API-HANDOFF-Block-Where-3.md`, 6 Oct
**Short version:** EWT_UI is VALID on all seven with 168 procedures. Compiling is not the same as
running: we ran all 68 query blocks and two fail with ORA-00936 from a generator bug. Six others
failed on our side and we fixed that. The `where=` registry stays. The atcorp link is fine on all
seven, and we checked where it actually points.

---

## 1. The package: VALID on all seven, as asked

| | |
|---|---|
| Instances with EWT_UI present, valid and current | 7 of 7 |
| Procedures per instance | 168, identical on all seven |
| Of those | 91 `_LOV_`, 66 `_W_`, 2 `_Q_`, 9 hand-written |
| Not VALID | 0 |

Confirmed through `/odata/proc?db=<instance>` on each, not from the deploy log alone. A second
restart with the package unchanged issued no `CREATE OR REPLACE` on any instance, so nothing will
hit ORA-04068 on a routine restart.

## 2. Compiling is not running: we ran all 68

Your check reported 105 ok, 0 failures. That is a compile check, and these procedures open their
query as **dynamic SQL inside `q'~...~'`**, so a malformed query compiles perfectly and fails only
when something calls it. We called all 68 on BCTN with every criterion null.

**Two fail, and the cause is one bug in the generator:**

```
AT1510_W_RNCNTNRS    ORA-00936: missing expression
AT1710_W_SRC         ORA-00936: missing expression
```

Both emit a doubled `WHERE`. The generator wraps the block's text in `WHERE (`, but for these two
the form's own text already starts with the keyword:

```sql
SELECT * FROM AT_OPPORTUNITIES_VIEW
 WHERE (
WHERE  AT_OPPORTUNITIES_VIEW.CUST_SEQ_ID = :w1 and
...
```

We searched the whole file: **exactly 2 of the 159 generated cursors** have `WHERE (` followed by a
line beginning `WHERE`, and they are exactly the two that fail. So stripping a leading `WHERE` from
the JDAPI text before wrapping it should fix both and affect nothing else.

We have **not** hand-patched `EWT_UI.sql`. It is inside your generated markers, so a patch would be
silently overwritten on your next run and would hide the bug. Regenerate and we will redeploy.

**Worth adding to `block-package.cjs`:** a run check, not only a compile check. Calling each
procedure with all-null criteria took us about four minutes for 68 and would have caught both.

## 3. Six more failed, and that one was ours

Six others returned HTTP 500 with `Specified cast is not valid`:

```
AT4230_W_CONTAINERS   AT5160_W_CNTNR1                 WB4000_W_OPEN_PARENTS
WB4000_W_OPEN_QTB     WB4000_W_WB_INCOMING_MANIFESTS  WB4100_W_WB_QTB_CONTAINERS_DAU
```

That is a .NET exception, not an Oracle one. Our REF CURSOR reader called `GetValue`, which calls
`GetDecimal`, which throws on an Oracle NUMBER carrying more significant digits than a .NET decimal
holds (38 against 28). The ordinary `$filter` query path already handled this; the cursor path never
had to until your query blocks started selecting those columns. Both now share one reader that falls
back to `OracleDecimal` at clamped precision. **All six pass.** Nothing is needed from you.

We also made that endpoint log its exception. It had been returning a 500 with only a message and no
stack, which is why this took longer to find than it should have.

**Current state on BCTN: 66 of 68 run, the 2 above excepted.**

## 4. The atcorp database link: present and pointing at dev on all seven

You flagged `AT1510_W_AT_CPS_VIEW`. We checked where that link actually goes rather than assuming,
because the daughters' links were pointed at **production** until late September and we wrote a test
row into prod through one.

Every instance resolves `ATCORP.ENERGYSOLUTIONS.COM` to the same database:

| | |
|---|---|
| DBID | 230091306 |
| Instance / host | `atcorp` on `dc1devewtdb1` |
| Version | 11.2.0.3.0, OPEN |
| `at_cnprodserv_view3` readable over it | yes, all seven |

`AT1510_W_AT_CPS_VIEW` runs successfully on all seven (0 rows with every criterion null, which is
what the WHERE gives when the binds are null). So this one is fine as it stands.

One oddity, not a problem: **CLUT** also carries a second link named
`ATCORP.ENERGYSOLUTIONS.COM@TEST` pointing at `EWT_CORP_TEST`. The name does not collide with
`@atcorp.energysolutions.com`, so nothing picks it up by accident. Flagging it so nobody is surprised
later.

## 5. The `where=` registry

Built, tested and staying. It costs nothing to leave in place and it is the only route for a block
the package does not hold. Three entries are registered (`AT5510.OUTSHIPMT`, `AT5511.OUTSHIPMT`,
`AT5521.OUTSHIPMT`) and `GET /admin/block-wheres` lists them. The four questions in -2 are closed, as
you asked.

If you would rather we drop it later, say so and we will, but there is no cost to keeping it.

## 6. Two reminders on `/odata/proc`

- It takes **`db=`**, not `instance=`.
- It returns one extra row per package with a **null `procedureName`**: the package-level row Oracle
  keeps in `ALL_PROCEDURES`. Filter it out. `EWT_UI` therefore shows 169 rows for 168 procedures.
