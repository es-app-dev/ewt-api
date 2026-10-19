"""
Keeps hand-added $expand relationships from being lost.

relationships.json is two things at once: 1,477 navigation properties generated from the
real Oracle foreign keys, and a growing set the UI team adds through
POST /admin/relationships for joins the foreign keys do not express, mostly onto views.

Those two have different lifetimes. The generated set is rebuilt from scratch every time
convert-schema-metadata.py runs, and the endpoint writes the hand-added ones into the same
file on whichever server is running. So a regeneration wipes the manual ones, and a deploy
overwrites the server's copy with ours. Both have to stop happening.

The split:

  relationships.generated.json   foreign keys, rebuilt, never edited by hand
  relationships.manual.json      hand-added, never generated, the thing worth protecting
  relationships.json             the union, which is what the API actually loads

Nothing at runtime changes: RelationshipService still reads relationships.json.

Used by convert-schema-metadata.py after it regenerates, and by pull-live-relationships.py
after it pulls from a running server.
"""

import json
import os

GENERATED = "EWT.Api/relationships.generated.json"
MANUAL = "EWT.Api/relationships.manual.json"
COMBINED = "EWT.Api/relationships.json"


def key(rel):
    """A relationship is identified by its source table and its navigation name."""
    return (rel["fromTable"].upper(), rel["name"])


def load(path):
    if not os.path.exists(path):
        return []
    with open(path, encoding="utf-8") as fh:
        return json.load(fh).get("relationships", [])


def save(path, rels, note):
    with open(path, "w", encoding="utf-8") as fh:
        json.dump({"note": note, "count": len(rels), "relationships": rels}, fh, indent=1)


def combine(verbose=True):
    """Rebuilds relationships.json as generated + manual. Manual wins a collision."""
    generated = load(GENERATED)
    manual = load(MANUAL)

    by_key = {key(r): r for r in generated}
    overridden = 0
    for rel in manual:
        if key(rel) in by_key:
            overridden += 1
        by_key[key(rel)] = rel

    combined = sorted(by_key.values(), key=lambda r: (r["fromTable"], r["name"]))
    save(COMBINED,
         combined,
         "Generated from Oracle foreign keys, plus hand-added entries from "
         "relationships.manual.json. Do not edit by hand: edit the manual file, or add "
         "through POST /admin/relationships and run scripts/pull-live-relationships.py.")

    if verbose:
        print(f"  generated : {len(generated)}")
        print(f"  manual    : {len(manual)}"
              + (f" ({overridden} overriding a generated one)" if overridden else ""))
        print(f"  combined  : {len(combined)}  -> {COMBINED}")
    return combined
