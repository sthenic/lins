import times
import strutils

import lexers.plain_text_lexer
import linters.plain_text_linter
import rules.rules
import rules.parser
import utils.log

var t_start, t_diff_ms: float

echo "Parsing rule directory"
t_start = cpu_time()
let RULES = parse_rule_dir("./vale")
# let RULES = parse_rule_file("./vale/Litotes.yml")
t_diff_ms = (cpu_time() - t_start) * 1000
echo "Parsing rule files took \x1B[1;32m", format_float(t_diff_ms, ffDecimal, 1), "\x1B[0m ms."

proc callback(s: Sentence) =
   for r in RULES:
      let violations = r.enforce(s)
      for v in violations:
         echo v.severity_str, ": ", v.message, " ", v.source_file

t_start = cpu_time()
lex_file("test_guardian.txt", callback)
t_diff_ms = (cpu_time() - t_start) * 1000
echo "Lexing took \x1B[1;32m", format_float(t_diff_ms, ffDecimal, 1), "\x1B[0m ms."
