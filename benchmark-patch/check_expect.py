"""Check each export against its fixture's .expect file (one regex per line)."""
import re, sys
from pathlib import Path
fixtures, out = Path(sys.argv[1]), Path(sys.argv[2])
failed = 0
for exp in sorted(fixtures.glob("*.expect")):
    text = (out / exp.name.replace(".expect", ".export.sysml")).read_text()
    for pattern in (l for l in exp.read_text().splitlines() if l.strip() and not l.startswith("#")):
        if not re.search(pattern, text):
            print(f"MISSING {exp.stem}: {pattern}")
            failed += 1
print("content checks:", "OK" if not failed else f"{failed} missing")
sys.exit(1 if failed else 0)
