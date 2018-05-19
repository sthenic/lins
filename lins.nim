import times
import strutils
import lexers.plain_text
import rules.rules
import rules.parser

var t_start, t_diff_ms: float

echo "Parsing rule directory"
t_start = cpu_time()
let RULES = parse_rule_dir("./vale")
t_diff_ms = (cpu_time() - t_start) * 1000
echo "Parsing rule files took \x1B[1;32m", format_float(t_diff_ms, ffDecimal, 1), "\x1B[0m ms."


proc callback(s: Sentence) =
   for r in RULES:
      let violations = r.enforce(s)
      for v in violations:
         echo v.severity_str, ": ", v.message

t_start = cpu_time()
lex_file("plain_benchmark.txt", callback)
t_diff_ms = (cpu_time() - t_start) * 1000
echo "Lexing took \x1B[1;32m", format_float(t_diff_ms, ffDecimal, 1), "\x1B[0m ms."
