import times
import strutils
import lexers.plain_text
import rules.rules

let RULES = @[
   RuleExistence.new(WARNING, "Consider removing '$1'.", "rules.txt", r"\b(wisdom|😇|Particular life)\b", true),
   RuleSubstitution.new(WARNING, "Consider using '$1' instead of '$2'.", "rules.txt", r"\bMarcus\b", "Mr. Eriksson", true),
   RuleOccurrence.new(WARNING, "More than 10 occurrences of the word 'me'.",
                      "rules.txt", r"\bme\b", 10, MAX, Scope.PARAGRAPH, true),
   RuleRepetition.new(WARNING, "Foo is repeated.", "rules.txt", r"\bfoo\b",
                      Scope.SENTENCE, true),
   RuleConsistency.new(WARNING, "Inconsistent spelling '$1'.", "rules.txt", r"\bfoo\b",
                       r"\bbar\b", Scope.TEXT, true),
   RuleDefinition.new(WARNING, "'$1' has no definition.", "rules.txt",
                       r"(?:\b[A-Z][a-z]+ )+\(([A-Z]{3,5})\)",
                       r"\b([A-Z]{3,5})\b", @["UV"], Scope.TEXT, false)
]

proc callback(s: Sentence) =
   for r in RULES:
      let violations = r.enforce(s)
      for v in violations:
         echo v.severity_str, ": ", v.message

let t_start = cpu_time()
lex_file("test_guardian.txt", callback)
let t_diff_ms = (cpu_time() - t_start) * 1000
echo "Lexing took \x1B[1;32m", format_float(t_diff_ms, ffDecimal, 1), "\x1B[0m ms."
