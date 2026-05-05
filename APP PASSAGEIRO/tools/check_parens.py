import sys
from pathlib import Path

p = Path(sys.argv[1])
text = p.read_text(encoding='utf-8')
open_paren = open_brace = open_bracket = 0

for i, line in enumerate(text.splitlines(), start=1):
    for ch in line:
        if ch == '(':
            open_paren += 1
        elif ch == ')':
            open_paren -= 1
        elif ch == '{':
            open_brace += 1
        elif ch == '}':
            open_brace -= 1
        elif ch == '[':
            open_bracket += 1
        elif ch == ']':
            open_bracket -= 1
    if open_paren < 0 or open_brace < 0 or open_bracket < 0:
        print(f"Mismatch at line {i}: paren={open_paren} brace={open_brace} bracket={open_bracket}")
        print(line)
        sys.exit(0)

print(f"Final counts: paren={open_paren} brace={open_brace} bracket={open_bracket}")
