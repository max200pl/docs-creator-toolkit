#!/usr/bin/env bash
# PostToolUse(Write): humanize report files in .claude/state/reports/.
# 1. Converts any machine-readable date in the body to human-readable format.
# 2. Renames the file itself to use a human-readable timestamp.
# Line 1 machine metadata comment is left untouched (for grep/diff tooling).
set -u

f=$(jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -z "$f" ] && exit 0

case "$f" in
  */.claude/state/reports/*.md) ;;
  *) exit 0 ;;
esac

[ ! -f "$f" ] && exit 0

# Step 1: humanize dates in body (skip line 1).
python3 - "$f" <<'PYEOF'
import sys, re
from datetime import datetime, timezone, timedelta

path = sys.argv[1]
with open(path, 'r') as fh:
    lines = fh.readlines()

# Patterns ordered longest-first so overlapping matches don't partially consume.
PATTERNS = [
    # ISO 8601 with milliseconds + Z:  2026-04-23T13:54:27.123Z
    (re.compile(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d+Z'), '%Y-%m-%dT%H:%M:%S.%fZ'),
    # ISO 8601 with numeric offset:    2026-04-23T13:54:27+05:30
    (re.compile(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{2}:\d{2}'), None),
    # ISO 8601 with Z:                 2026-04-23T13:54:27Z
    (re.compile(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z'), '%Y-%m-%dT%H:%M:%SZ'),
    # Compact datetime in body:        20260423-135427
    (re.compile(r'\b(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})(\d{2})\b'), 'compact'),
]

def parse_offset(s):
    """Parse ISO 8601 with +HH:MM or -HH:MM offset."""
    dt_part, off = s[:-6], s[-6:]
    sign = 1 if off[0] == '+' else -1
    h, m = int(off[1:3]), int(off[4:6])
    dt = datetime.strptime(dt_part, '%Y-%m-%dT%H:%M:%S')
    dt = dt - timedelta(hours=sign * h, minutes=sign * m)
    return dt.replace(tzinfo=timezone.utc)

def humanize_match(pattern, fmt, m):
    s = m.group(0)
    try:
        if fmt == 'compact':
            dt = datetime(int(m.group(1)), int(m.group(2)), int(m.group(3)),
                          int(m.group(4)), int(m.group(5)), int(m.group(6)),
                          tzinfo=timezone.utc)
        elif fmt is None:
            dt = parse_offset(s)
        else:
            dt = datetime.strptime(s, fmt).replace(tzinfo=timezone.utc)
        return dt.strftime('%b %d, %Y %H:%M UTC')
    except (ValueError, AttributeError):
        return s

def humanize_line(line):
    for pattern, fmt in PATTERNS:
        line = pattern.sub(lambda m, p=pattern, f=fmt: humanize_match(p, f, m), line)
    return line

# Line 0 = machine metadata comment — keep as-is.
result = [lines[0]] if lines else []
for line in lines[1:]:
    result.append(humanize_line(line))

with open(path, 'w') as fh:
    fh.writelines(result)
PYEOF

# Step 2: rename file — convert compact timestamp in filename to human-readable.
# Pattern: <skill>-YYYYMMDD-HHMMss.md → <skill>-Mon-DD-YYYY-HHMM.md
dir=$(dirname "$f")
base=$(basename "$f" .md)

new_base=$(python3 - "$base" <<'PYEOF'
import sys, re
from datetime import datetime

base = sys.argv[1]
m = re.search(r'^(.+)-(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})\d{2}$', base)
if not m:
    print(base)
    sys.exit(0)

prefix = m.group(1)
try:
    dt = datetime(int(m.group(2)), int(m.group(3)), int(m.group(4)),
                  int(m.group(5)), int(m.group(6)))
    print(f"{prefix}-{dt.strftime('%b-%d-%Y-%H%M')}")
except ValueError:
    print(base)
PYEOF
)

new_f="$dir/$new_base.md"

if [ "$new_f" != "$f" ] && [ ! -f "$new_f" ]; then
    mv "$f" "$new_f"
    jq -n --arg msg "Report saved as: $new_f" '{systemMessage: $msg}'
fi

exit 0
