# Maps diagnostics on the assembled script back to their origin.
# Input: array of { line, column, level, code, message }; $map: [sourcemap].
def segment($l): first($map[0].segments[] | select(.start <= $l and $l <= .end)) // null;

.[]
| . as $d
| segment($d.line) as $s
| (if $s == null then "\($map[0].file):\($d.line)"
   elif $s.origin.kind == "user" then "\($s.origin.file):\($d.line - $s.start + 1)"
   else "\($map[0].file):\($d.line) [\($s.origin.label)]"
   end) as $loc
| "\($loc):\($d.column // 0): \($d.level): \($d.message)"
  + (if $d.code then " [\($d.code)]" else "" end)
  + (if $s != null and $s.origin.kind != "user" then
       "\n    (in generated/library code, this is a nix-scripter bug)"
     else "" end)
