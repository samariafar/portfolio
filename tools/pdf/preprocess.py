#!/usr/bin/env python3
"""Make a Zola-flavored resume markdown file digestible by pandoc.

- Strips the leading TOML frontmatter (`+++ ... +++`), which pandoc treats as
  literal text.
- Expands the `{{ years_since(start=YYYY) }}` shortcode the way the Tera
  template does, so the rendered year-count is identical between the website
  and the PDF.
"""

import datetime
import re
import sys

FRONTMATTER_RE = re.compile(r"^\+\+\+\r?\n.*?\n\+\+\+\r?\n", re.DOTALL)
YEARS_SINCE_RE = re.compile(r"\{\{\s*years_since\(start=(\d+)\)\s*\}\}")
EMOJI_RE = re.compile(
    "["
    "\U0001F1E0-\U0001F1FF"  # regional indicator symbols (flag halves)
    "\U0001F300-\U0001F5FF"  # symbols & pictographs
    "\U0001F600-\U0001F64F"  # emoticons
    "\U0001F680-\U0001F6FF"  # transport & map
    "\U0001F900-\U0001F9FF"  # supplemental symbols & pictographs
    "\U0001FA70-\U0001FAFF"  # symbols & pictographs extended-A
    "\U00002600-\U000026FF"  # miscellaneous symbols
    "\U00002700-\U000027BF"  # dingbats
    "]+",
    flags=re.UNICODE,
)


def main():
    text = sys.stdin.read()
    text = FRONTMATTER_RE.sub("", text, count=1)
    current_year = datetime.date.today().year
    text = YEARS_SINCE_RE.sub(lambda m: str(current_year - int(m.group(1))), text)
    text = EMOJI_RE.sub("", text)
    text = text.replace("&nbsp;", "") #  
    sys.stdout.write(text)


if __name__ == "__main__":
    main()
