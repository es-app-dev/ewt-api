"""
Checks that the fragments in OurPackages/ewt_ui still add up to the EWT_UI package.

Byte-identical reassembly is not the test, and cannot be: the original file interleaves
forms (AT5510's hand-written code sits early, its generated list-of-values procedures much
later), so grouping by form necessarily reorders. What must hold instead:

  1. Lossless. Every slice of the original appears exactly once across the fragments and
     the frame, and nothing else does. Reordering is allowed; losing or duplicating a
     procedure is not.
  2. Same surface. The same 168 spec declarations and 176 body definitions.
  3. Order-safe. PL/SQL needs a package-body-private procedure defined before anything
     calls it. Public procedures are declared in the spec and may appear in any order, so
     only the 8 private ones constrain the layout.

Compiling the assembled package is the final word, and the API does that against the real
instances. This runs without a database.

Usage:
    python scripts/verify-ewt-ui-split.py
"""

import io
import json
import os
import re
import sys
from collections import Counter

SOURCE = os.path.join("OurPackages", "EWT_UI.sql")
OUTDIR = os.path.join("OurPackages", "ewt_ui")

SECTION = re.compile(r"(?m)^--#([A-Z-]+)\n")
TOP_LEVEL = re.compile(r"(?m)^  (?:PROCEDURE|FUNCTION)\s+([a-z0-9_]+)")


def sections(text):
    out = {}
    marks = list(SECTION.finditer(text))
    for i, m in enumerate(marks):
        end = marks[i + 1].start() if i + 1 < len(marks) else len(text)
        out[m.group(1)] = text[m.end():end]
    return out


def load():
    frame = sections(io.open(os.path.join(OUTDIR, "_frame.sql"), encoding="utf-8").read())
    manifest = json.load(io.open(os.path.join(OUTDIR, "_manifest.json"), encoding="utf-8"))

    listed = manifest["order"]
    present = sorted(f[:-4] for f in os.listdir(OUTDIR)
                     if f.endswith(".sql") and f != "_frame.sql")
    extra = [f for f in present if f not in listed]
    order = [f for f in listed if f in present] + sorted(extra)

    frags = {}
    for name in order:
        frags[name] = sections(
            io.open(os.path.join(OUTDIR, "%s.sql" % name), encoding="utf-8").read())
    return frame, order, frags, extra


def assemble(frame, order, frags):
    return (frame["PREAMBLE"]
            + frame["SPEC-OPEN"]
            + frame["SPEC-HEAD"]
            + "".join(frags[n].get("SPEC", "") for n in order)
            + frame["SPEC-TAIL"]
            + frame["BODY-OPEN"]
            + frame["BODY-HEAD"]
            + "".join(frags[n].get("BODY", "") for n in order)
            + frame["BODY-TAIL"])


def main():
    if not os.path.isdir(OUTDIR):
        sys.exit("%s not found; run scripts/split-ewt-ui.py first." % OUTDIR)

    original = io.open(SOURCE, encoding="utf-8").read()
    frame, order, frags, extra = load()
    rebuilt = assemble(frame, order, frags)

    ok = True
    print("  fragments: %d%s" % (
        len(order), (" (%d not in the manifest)" % len(extra)) if extra else ""))

    # 1. Lossless, allowing reorder: same characters, same count.
    if Counter(original) == Counter(rebuilt):
        print("  lossless          : yes (%d chars, same multiset)" % len(rebuilt))
    else:
        ok = False
        lost = Counter(original) - Counter(rebuilt)
        gained = Counter(rebuilt) - Counter(original)
        print("  lossless          : NO  (%d chars missing, %d added)"
              % (sum(lost.values()), sum(gained.values())))

    # 2. Same surface.
    def names(text, which):
        at = text.index("CREATE OR REPLACE PACKAGE BODY")
        return set(TOP_LEVEL.findall(text[:at] if which == "spec" else text[at:]))

    for which in ("spec", "body"):
        a, b = names(original, which), names(rebuilt, which)
        if a == b:
            print("  %-4s declarations : %d, unchanged" % (which, len(a)))
        else:
            ok = False
            print("  %-4s declarations : CHANGED  missing=%s added=%s"
                  % (which, sorted(a - b), sorted(b - a)))

    # 3. Private helpers defined before first use, in the assembled body.
    body_at = rebuilt.index("CREATE OR REPLACE PACKAGE BODY")
    spec_text, body_text = rebuilt[:body_at], rebuilt[body_at:]
    private = set(TOP_LEVEL.findall(body_text)) - set(TOP_LEVEL.findall(spec_text))

    late = []
    for name in sorted(private):
        definition = re.search(r"(?m)^  (?:PROCEDURE|FUNCTION)\s+%s\b" % re.escape(name),
                               body_text)
        if not definition:
            continue
        for m in re.finditer(r"(?<![a-z0-9_])%s\s*[(;]" % re.escape(name), body_text, re.I):
            before = body_text[max(0, m.start() - 40):m.start()].lower()
            if re.search(r"(procedure|function|end)\s*$", before):
                continue
            if m.start() < definition.start():
                late.append((name, m.start(), definition.start()))
            break

    if late:
        ok = False
        print("  private ordering  : NO - called before defined:")
        for name, call, defn in late:
            print("     %s called at %d but defined at %d" % (name, call, defn))
    else:
        print("  private ordering  : ok (%d private helpers, each defined before use)"
              % len(private))

    print()
    print("  RESULT: %s" % ("the fragments still make the package" if ok else "BROKEN"))
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
