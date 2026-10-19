# 68 of 68 run. And the timeout answer: there isn't one

**From:** the API side (`C:\essource\ewt-api`)
**Date:** 2026-10-06
**Answers:** `API-HANDOFF-Block-Where-4.md`, 6 Oct
**Short version:** deployed and restarted. All 68 run. Your three slow procedures are not the three
slowest: the one you just fixed is the slowest of the lot at 110 seconds. On the timeout, nothing in
the API imposes one, which is its own problem.

---

## 1. Deployed and verified

The regenerated file is in. The diff against what was deployed is the two lines you described, one
in each procedure, and no cursor in the file now has `WHERE (` followed by a line starting `WHERE`.

| | |
|---|---|
| EWT_UI present, valid and current | 7 of 7 instances |
| Procedures per instance | 168, identical on all seven, 0 invalid |
| Query blocks run on BCTN | **68 of 68** |
| Second restart, package unchanged | 0 `CREATE OR REPLACE` issued |

Both previously failing procedures now run:

```
AT1510_W_RNCNTNRS   ok, 5000 rows
AT1710_W_SRC        ok
```

## 2. Your slow list is missing its biggest entry

You timed three. We timed all 68, twice. The ranking is different, because **AT1510_W_RNCNTNRS was
failing when you measured**, so it never appeared:

| Procedure | Your time | Ours (two runs) | Rows |
|---|---:|---:|---:|
| **`AT1510_W_RNCNTNRS`** | not timed, was failing | **115.4 s / 110.2 s** | 5000 |
| `AT5514_W_OUTCNTNR` | 71 s | 65.3 s / 62.6 s | 0 |
| `AT4151_W_LINER_CREATE` | 20 s | 20.6 s | 0 |
| `WB4000_W_WB_INCOMING_MANIFESTS` | 14 s | 20.1 s | 465 |
| `AT5511_W_OUTSHIPMT` |: | 19.4 s | 5000 |
| `AT5510_W_AT_OUTBOUND_SHIPMENTS` |: | 18.4 s | 5000 |

So the number to design against is **110 seconds, not 71**. Worth re-running your check now that it
passes, so your own table reflects it.

Note AT1510_W_RNCNTNRS is returning the full 5,000-row cap, so that 110 s is the cost of filling the
cap, not of a single expensive row. A real screen sends criteria and will be faster. The all-null
case is the worst case, which is the right thing to measure, but do not read it as the user's wait.

## 3. The timeout: there is no limit, and that is not a good thing

You asked what the limit is. The honest answer is that the API does not set one anywhere:

- **The procedure call:** `OracleProcedureService` sets no `CommandTimeout`, so ODP.NET's default
  applies, which is no limit. The call waits as long as Oracle takes.
- **The HTTP request:** no Kestrel request timeout is configured, and `web.config` sets no ANCM
  `requestTimeout`. We host in-process, where that attribute does not apply in any case.

Measured rather than inferred:

- Through the **live dev server** (`ewt-dev-api.energysolutions.com`, so through IIS):
  `AT5514_W_OUTCNTNR` returned normally in **64.8 s**.
- Locally: `AT1510_W_RNCNTNRS` returned normally in **110 s**.

So nothing cuts you off at 71 s, and nothing will cut you off at 110 s either.

**The flip side, and we would rather raise it than leave it:** an unbounded procedure call is a
hazard. A procedure that hangs holds its Oracle session and its connection indefinitely, and enough
of those will exhaust the pool and take the API down for everyone, not just the screen that made the
call. The legacy forms had a user who could close the window; an HTTP client that gives up leaves
our side still waiting.

We have **not** changed anything, because a limit is a decision with a real cost: anything under
roughly 150 s would break AT1510_W_RNCNTNRS in its all-null case, and we are not going to impose
that on you quietly.

**Our recommendation, for Bruce to settle:** a `CommandTimeout` of **300 seconds** on procedure
execution. It is roughly triple the slowest real case, so no screen that works today would start
failing, and it turns a hung call into a clean error after five minutes instead of a leaked
connection forever. If you would rather have a per-call override, say so and we will take the value
from a query parameter with 300 s as the default and a ceiling.

Tell us which you want and we will put it in the next dist.

## 4. The run check

Good. Two suggestions from running ours alongside it:

- **Record the elapsed time per procedure, not just pass or fail.** That is what surfaced
  AT1510_W_RNCNTNRS as the real outlier.
- **Raise your 90-second per-call limit.** At 90 s it will report AT1510_W_RNCNTNRS as a failure
  when the procedure is fine and simply slow, which is exactly the false alarm that costs an
  afternoon. 300 s would match the limit we are proposing above.

## 5. Nothing else changed

Catalogue, relationships, sequences, `$count`, synonym reads and the `where=` registry are all
unchanged from the 6 Oct dist: BCTN 1579 (1477 owned + 102 via synonym), 1525 relationships, 85
sequences, 3 block WHEREs, 20 Swagger operations, AT_CUSTOMERS 8001 on both BCTN and CORP.
