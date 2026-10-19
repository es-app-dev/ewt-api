"""
Splits a single-file EWT_UI.sql into one fragment per form.

HISTORICAL. This was run once, on 2026-10-19, to produce OurPackages/ewt_ui from the
350 KB EWT_UI.sql that preceded it. That file has since been deleted, so this script
has no input unless someone recreates one with scripts/assemble-ewt-ui.py. Kept
because it documents exactly how the 168 procedures were apportioned to 60 forms.

Run once to convert the monolith. After that the fragments are the source and nothing
regenerates them from the whole file; the UI side edits a form's fragment through the API
and the API merges them back into one EWT_UI package before deploying.

The split is a verbatim slice, never a reformat. A fragment runs from the start of one
top-level procedure to the start of the next, taking any comment block immediately above it.
Reassembling the frame and the fragments in manifest order therefore reproduces the original
file byte for byte, which is what verify-ewt-ui-split.py checks.

Slicing at procedure starts rather than at END avoids matching PL/SQL block structure: only
17 of 344 definitions in this file close with "END <name>;", the rest use a bare "END;".

Usage:
    python scripts/split-ewt-ui.py                 # writes OurPackages/ewt_ui/
    python scripts/split-ewt-ui.py --dry-run
"""

import argparse
import io
import json
import os
import re
import sys

SOURCE = os.path.join("OurPackages", "EWT_UI.sql")
OUTDIR = os.path.join("OurPackages", "ewt_ui")

# A top-level unit in either the spec or the body: PROCEDURE or FUNCTION at exactly
# two spaces of indent, which is this file's convention throughout.
TOP_LEVEL = re.compile(r"(?m)^  (?:PROCEDURE|FUNCTION)\s+([A-Za-z0-9_]+)")

# Which form a procedure belongs to. Everything else is shared and goes to _common.
FORM_OF = re.compile(r"^(at\d{4}|wb\d{4})_", re.IGNORECASE)

SPEC_OPEN = re.compile(r"(?im)^CREATE OR REPLACE PACKAGE ewt_ui\b.*$")
BODY_OPEN = re.compile(r"(?im)^CREATE OR REPLACE PACKAGE BODY ewt_ui\b.*$")
UNIT_CLOSE = re.compile(r"(?im)^END ewt_ui\s*;\s*$")


def form_of(name):
    m = FORM_OF.match(name)
    return m.group(1).upper() if m else "_COMMON"


def line_starts(text):
    """Character offset of the start of every line, so slicing stays exact."""
    offsets = [0]
    for i, ch in enumerate(text):
        if ch == "\n":
            offsets.append(i + 1)
    return offsets


def comment_start(text, pos, starts):
    """
    Offset of the first line of the comment block directly above pos.

    Works in line numbers against a precomputed offset table rather than by
    re-joining text, which is where an earlier version lost a newline and made the
    reassembly one byte short at each boundary.
    """
    # The line pos sits on.
    lo, hi = 0, len(starts) - 1
    while lo < hi:
        mid = (lo + hi + 1) // 2
        if starts[mid] <= pos:
            lo = mid
        else:
            hi = mid - 1
    line = lo

    lines = text.split("\n")

    def is_comment(n):
        s = lines[n].strip()
        return s.startswith("--") or s.startswith("*") or s.startswith("/*")

    keep = line
    n = line - 1
    while n >= 0:
        if is_comment(n):
            keep = n
            n -= 1
        elif lines[n].strip() == "":
            # Absorb a blank line only when more comment sits above it.
            j = n
            while j >= 0 and lines[j].strip() == "":
                j -= 1
            if j >= 0 and is_comment(j):
                n = j
            else:
                break
        else:
            break

    return starts[keep]


def carve(section_text):
    """Returns (head, [(name, slice)], tail) for one package unit's inner text."""
    starts = [(m.start(), m.group(1)) for m in TOP_LEVEL.finditer(section_text)]
    if not starts:
        return section_text, [], ""

    # Pull each procedure's leading comment block into its own slice.
    starts_table = line_starts(section_text)
    bounds = []
    for pos, name in starts:
        bounds.append((comment_start(section_text, pos, starts_table), name))

    head = section_text[: bounds[0][0]]
    pieces = []
    for idx, (start, name) in enumerate(bounds):
        end = bounds[idx + 1][0] if idx + 1 < len(bounds) else len(section_text)
        pieces.append((name, section_text[start:end]))

    # Whatever trails the last procedure before END belongs to the frame, not to a form.
    last_name, last_text = pieces[-1]
    tail = ""
    close = UNIT_CLOSE.search(last_text)
    if close:
        tail = last_text[close.start():]
        pieces[-1] = (last_name, last_text[: close.start()])

    return head, pieces, tail


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    if not os.path.exists(SOURCE):
        sys.exit("%s not found; run from the repo root." % SOURCE)

    text = io.open(SOURCE, encoding="utf-8").read()

    spec_open = SPEC_OPEN.search(text)
    body_open = BODY_OPEN.search(text)
    if not spec_open or not body_open:
        sys.exit("Could not find both CREATE OR REPLACE PACKAGE and PACKAGE BODY lines.")

    # Everything before the spec's CREATE line is the file preamble, and the slash lines
    # between and after the two units are part of the frame.
    preamble = text[: spec_open.start()]
    # +1 steps over the newline that ends the CREATE line; the frame puts it back when
    # it writes the OPEN section, so the two must not both carry it.
    spec_inner = text[spec_open.end() + 1: body_open.start()]
    body_inner = text[body_open.end() + 1:]

    spec_head, spec_pieces, spec_tail = carve(spec_inner)
    body_head, body_pieces, body_tail = carve(body_inner)

    print("  spec: %d top-level declarations" % len(spec_pieces))
    print("  body: %d top-level definitions" % len(body_pieces))

    forms = {}
    order = []
    for name, chunk in spec_pieces:
        f = form_of(name)
        if f not in forms:
            forms[f] = {"spec": [], "body": [], "procs": []}
            order.append(f)
        forms[f]["spec"].append(chunk)
        forms[f]["procs"].append(name)

    for name, chunk in body_pieces:
        f = form_of(name)
        if f not in forms:
            forms[f] = {"spec": [], "body": [], "procs": []}
            order.append(f)
        forms[f]["body"].append(chunk)
        if name not in forms[f]["procs"]:
            forms[f]["procs"].append(name)

    # _COMMON holds the shared helpers and must be emitted first in the body, because
    # the file's current order defines them before anything calls them.
    if "_COMMON" in order:
        order.remove("_COMMON")
        order.insert(0, "_COMMON")

    print("  fragments: %d (%s)" % (len(order), ", ".join(order[:6]) + ", ..."))

    if args.dry_run:
        for f in order:
            print("    %-10s spec %2d  body %2d" % (f, len(forms[f]["spec"]), len(forms[f]["body"])))
        return

    if not os.path.isdir(OUTDIR):
        os.makedirs(OUTDIR)

    frame = (
        "--#PREAMBLE\n" + preamble
        + "--#SPEC-OPEN\n" + spec_open.group(0) + "\n"
        + "--#SPEC-HEAD\n" + spec_head
        + "--#SPEC-TAIL\n" + spec_tail
        + "--#BODY-OPEN\n" + body_open.group(0) + "\n"
        + "--#BODY-HEAD\n" + body_head
        + "--#BODY-TAIL\n" + body_tail
    )
    io.open(os.path.join(OUTDIR, "_frame.sql"), "w", encoding="utf-8", newline="").write(frame)

    for f in order:
        parts = forms[f]
        out = (
            "-- EWT_UI fragment: %s\n" % f
            + "-- Assembled into the EWT_UI package by the API. No CREATE OR REPLACE here,\n"
            + "-- and no slash lines: the frame supplies those.\n"
            + "--#SPEC\n" + "".join(parts["spec"])
            + "--#BODY\n" + "".join(parts["body"])
        )
        io.open(os.path.join(OUTDIR, "%s.sql" % f), "w", encoding="utf-8", newline="").write(out)

    manifest = {
        "package": "EWT_UI",
        "note": "Order is the order the original EWT_UI.sql defined these in. The API "
                "assembles in this order; a fragment not listed here is appended "
                "alphabetically after the listed ones.",
        "splitFrom": SOURCE,
        "order": order,
        "fragments": {f: {"procedures": forms[f]["procs"],
                          "specDeclarations": len(forms[f]["spec"]),
                          "bodyDefinitions": len(forms[f]["body"])} for f in order},
    }
    io.open(os.path.join(OUTDIR, "_manifest.json"), "w", encoding="utf-8", newline="").write(
        json.dumps(manifest, indent=2) + "\n")

    print("  wrote %d fragments, _frame.sql and _manifest.json to %s" % (len(order), OUTDIR))


if __name__ == "__main__":
    main()
