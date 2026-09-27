# Input: array of { line, column, level, code, message } on the assembled
# script; $map: [sourcemap]. Output: one report line per diagnostic.
def segment($line): first($map[0].segments[] | select(.start <= $line and $line <= .end)) // null;

def location($d; $s):
  if $s == null then "\($map[0].file):\($d.line)"
  elif $s.origin.kind == "user" then "\($s.origin.file):\($d.line - $s.start + 1)"
  else "\($map[0].file):\($d.line) [\($s.origin.label)]"
  end;

def code_suffix($d): if $d.code then " [\($d.code)]" else "" end;

def bug_note($s):
  if $s != null and $s.origin.kind != "user"
  then "\n    (in generated or library code: this is a nix-scripter bug)"
  else "" end;

.[]
| . as $d
| segment($d.line) as $s
| "\(location($d; $s)):\($d.column // 0): \($d.level): \($d.message)\(code_suffix($d))\(bug_note($s))"
