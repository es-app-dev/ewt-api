"""
Assembles OurPackages/ewt_ui/*.sql into one EWT_UI package.

This is the reference for what the API does on load and on a deploy request. Kept as a
script so the assembly can be produced and inspected without running the server, and so the
two implementations can be compared against each other.

Order: the manifest's order first, then any fragment not listed, alphabetically. _COMMON is
first in the manifest because rule_error lives there and four other fragments call it; a
package-body-private procedure has to be defined before anything calls it.

Usage:
    python scripts/assemble-ewt-ui.py                      # to stdout
    python scripts/assemble-ewt-ui.py -o build/EWT_UI.sql
"""

import argparse
import io
import json
import os
import re
import sys

OUTDIR = os.path.join("OurPackages", "ewt_ui")
KNOWN_SECTIONS = {
    "SPEC", "BODY",
    "PREAMBLE", "SPEC-OPEN", "SPEC-HEAD", "SPEC-TAIL",
    "BODY-OPEN", "BODY-HEAD", "BODY-TAIL",
}

SECTION = re.compile(r"(?m)^--#([A-Z-]+)\n")


def sections(text):
    out = {}
    marks = [m for m in SECTION.finditer(text)
             if m.group(1) in KNOWN_SECTIONS]
    for i, m in enumerate(marks):
        end = marks[i + 1].start() if i + 1 < len(marks) else len(text)
        out[m.group(1)] = text[m.end():end]
    return out


def fragment_order(directory=OUTDIR):
    manifest = json.load(io.open(os.path.join(directory, "_manifest.json"), encoding="utf-8"))
    listed = manifest["order"]
    present = sorted(f[:-4] for f in os.listdir(directory)
                     if f.endswith(".sql") and f != "_frame.sql")
    return [f for f in listed if f in present] + sorted(f for f in present if f not in listed)


def assemble(directory=OUTDIR):
    frame = sections(io.open(os.path.join(directory, "_frame.sql"), encoding="utf-8").read())
    order = fragment_order(directory)

    specs, bodies = [], []
    for name in order:
        parts = sections(io.open(os.path.join(directory, "%s.sql" % name), encoding="utf-8").read())
        specs.append(parts.get("SPEC", ""))
        bodies.append(parts.get("BODY", ""))

    return (frame["PREAMBLE"]
            + frame["SPEC-OPEN"]
            + frame["SPEC-HEAD"]
            + "".join(specs)
            + frame["SPEC-TAIL"]
            + frame["BODY-OPEN"]
            + frame["BODY-HEAD"]
            + "".join(bodies)
            + frame["BODY-TAIL"])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-o", "--out")
    ap.add_argument("-d", "--dir", default=OUTDIR)
    args = ap.parse_args()

    text = assemble(args.dir)

    if args.out:
        parent = os.path.dirname(args.out)
        if parent and not os.path.isdir(parent):
            os.makedirs(parent)
        io.open(args.out, "w", encoding="utf-8", newline="").write(text)
        print("  %d fragments -> %s (%d bytes)"
              % (len(fragment_order(args.dir)), args.out, len(text)))
    else:
        sys.stdout.write(text)


if __name__ == "__main__":
    main()
