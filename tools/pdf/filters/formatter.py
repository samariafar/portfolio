#!/usr/bin/env python3
"""Pandoc filter for the resume PDF generator.

Two behaviors, both keyed on pandoc-generated header slugs:

- TRUNCATE_HEADERS: when matched, the header and every block after it are
  dropped. Used to cut everything from "Engagements" onwards.
- DROP_HEADERS: when matched, the header and its section body are dropped,
  but everything after the section (the next sibling header at the same or
  higher level, plus the rest of the document) is kept. Used to hide
  individual sections like "Certificates".
"""

import json
import sys

TRUNCATE_HEADERS_BY_LANG = {
    "en": "engagements",
}

DROP_HEADERS_BY_LANG = [
    {
        "en": "certificates",
    },
]

TRUNCATE_HEADERS = set(TRUNCATE_HEADERS_BY_LANG.values())
DROP_HEADERS = {slug for entry in DROP_HEADERS_BY_LANG for slug in entry.values()}

# Horizontal-rule rendering. STRIP_HORIZONTAL_RULES = True removes every `---`
# from the PDF deterministically; False renders each as a centred, 90%-wide
# rule (vs. pandoc's default 50%). The HR pass runs before DROP/TRUNCATE, so
# rules in dropped/truncated regions aren't collaterally lost when the flag
# is False — they're either explicitly kept or explicitly stripped.
STRIP_HORIZONTAL_RULES = False
HR_RAW_LATEX = r"\begin{center}\textcolor[HTML]{00ADEF}{\rule{\linewidth}{0.5pt}}\end{center}"


def main():
    doc = json.load(sys.stdin)
    blocks = doc.get("blocks", [])
    kept = []
    drop_until_level = None

    for block in blocks:
        if block.get("t") == "HorizontalRule":
            if not STRIP_HORIZONTAL_RULES:
                kept.append({"t": "RawBlock", "c": ["latex", HR_RAW_LATEX]})
            continue

        if drop_until_level is not None:
            if block.get("t") == "Header":
                level = block["c"][0]
                if level <= drop_until_level:
                    drop_until_level = None
                else:
                    continue
            else:
                continue

        if block.get("t") == "Header":
            level = block["c"][0]
            slug = block["c"][1][0]
            if slug in TRUNCATE_HEADERS:
                break
            if slug in DROP_HEADERS:
                drop_until_level = level
                continue

        kept.append(block)

    doc["blocks"] = kept
    json.dump(doc, sys.stdout)


if __name__ == "__main__":
    main()
