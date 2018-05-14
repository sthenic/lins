import times
import strutils
import lexers.plain_text
import rules.rules

let RULES = @[
   RuleExistence.new(WARNING, "Consider removing '$1'.", "rules.txt", r"\b(wisdom|😇|Particular life)\b", true),
   RuleExistence.new(ERROR, "Consider removing '$1'.", "rules.txt", "😇", true),
   RuleExistence.new(ERROR, "Consider removing '$1'.", "rules.txt", r"\b(Basic pattern)\b", true),
   RuleExistence.new(ERROR, "Consider removing '$1'.", "rules.txt", r"\b(King|county)\b", true)
]

proc callback(s: Sentence) =
   for r in RULES:
      let violations = r.enforce(s)
      for v in violations:
         echo v.severity_str, ": ", v.message

let t_start = cpu_time()
lex_file("plain_benchmark.txt", callback)
let t_diff_ms = (cpu_time() - t_start) * 1000
echo "Lexing took \x1B[1;32m", format_float(t_diff_ms, ffDecimal, 1), "\x1B[0m ms."
