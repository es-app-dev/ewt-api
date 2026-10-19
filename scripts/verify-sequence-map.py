"""
Proves, against live data, that every column the server allocates is actually unique.

This is the check that caught three bad entries in the sequence map after both sides had
reasoned their way to the wrong answer from the forms. Reading the PL/SQL tells you what a
form allocates NEAR a table; only the data tells you what allocates THAT table's column.
So it is a script rather than a thing someone remembers to do.

For each entry it runs, per instance:

    $apply=aggregate($count as rows, <column> with countdistinct as d)

which is COUNT(*) against COUNT(DISTINCT col) in one Oracle query, with no row cap. Equal
means the column is allocated per row. Fewer distinct than rows means it is a reference to
something else and must not be auto-assigned.

Two rules learned the hard way, both enforced here:

  Check the instance with the data. On CORP the invoice tables are empty and the same
  query answers "unique" on zero rows, which is how a bad entry nearly shipped. Instances
  with no rows are reported as UNPROVEN, never as passing.

  Do not stop at the first instance that works. A column can be unique on one site and
  reused on another; AT_BATCH_DAUGHTERS is unique on CLUT and reused on BCTN.

Usage:
    python scripts/verify-sequence-map.py [--base http://localhost:5282] [--table NAME]

Exit code is 1 if anything failed, so it can gate a deploy.
"""

import argparse
import json
import sys
import urllib.error
import urllib.parse
import urllib.request

MAP = "EWT.Api/sequences.json"
DEFAULT_BASE = "http://localhost:5282"
TIMEOUT = 180


def get(url):
    with urllib.request.urlopen(url, timeout=TIMEOUT) as response:
        return json.load(response)


def instances(base):
    data = get(f"{base}/odata/instances")
    return [i["name"] for i in data["instances"]]


def counts(base, instance, table, column):
    """Rows and distinct values, or None when the entity is absent on this instance."""
    apply_expr = f"aggregate($count as rows,{column} with countdistinct as d)"
    url = (f"{base}/odata/{table}?db={instance}"
           f"&$apply={urllib.parse.quote(apply_expr, safe='(),$')}")
    try:
        row = get(url)["value"][0]
        return int(row["rows"]), int(row["d"])
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return None          # not on this instance, which is normal
        raise


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", default=DEFAULT_BASE, help="running API base url")
    parser.add_argument("--table", help="verify one table instead of all of them")
    args = parser.parse_args()

    entries = json.load(open(MAP, encoding="utf-8"))["assign"]
    if args.table:
        key = args.table.upper()
        entries = {k: v for k, v in entries.items() if k.upper() == key}
        if not entries:
            sys.exit(f"{args.table} is not in {MAP}")

    try:
        every_instance = instances(args.base)
    except Exception as e:
        sys.exit(f"Could not reach {args.base}: {e}\nStart the API first.")

    reused, unproven, proven = [], [], []

    for table, entry in sorted(entries.items()):
        column = entry["column"]
        rows_seen = 0
        worst = None

        for instance in every_instance:
            try:
                result = counts(args.base, instance, table, column)
            except Exception as e:
                print(f"  {table:<34}{instance:<7}ERROR {e}")
                worst = worst or ("error", instance, 0, 0)
                continue

            if result is None:
                continue
            rows, distinct = result
            if rows == 0:
                continue

            rows_seen += rows
            if rows != distinct:
                print(f"  {table:<34}{instance:<7}rows={rows:<9}distinct={distinct:<9}REUSED")
                worst = ("reused", instance, rows, distinct)

        if worst and worst[0] == "reused":
            reused.append((table, column, worst))
        elif rows_seen == 0:
            unproven.append((table, column))
        else:
            proven.append((table, column, rows_seen))

    print()
    print(f"  verified against {args.base}")
    print(f"  proven unique on live data : {len(proven)}")
    print(f"  no rows anywhere, unproven : {len(unproven)}")
    print(f"  REUSED, must be removed    : {len(reused)}")

    if unproven:
        print("\n  Unproven. Empty on every instance, so the data cannot confirm or deny:")
        for table, column in unproven:
            print(f"    {table}.{column}")

    if reused:
        print("\n  FAILED. These are not allocators and must come out of the map:")
        for table, column, (_, instance, rows, distinct) in reused:
            print(f"    {table}.{column} on {instance}: {rows} rows, {distinct} distinct")
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
