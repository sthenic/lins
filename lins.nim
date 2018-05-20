import times
import strutils

import linters.plain_text_linter
import rules.rules
import rules.parser
import utils.log

var t_start, t_diff_ms: float

let filename = "test_guardian.txt"

echo "Parsing rule directory"
t_start = cpu_time()
let RULES = parse_rule_dir("./vale")
# let RULES = parse_rule_file("./vale/Litotes.yml")
t_diff_ms = (cpu_time() - t_start) * 1000
echo "Parsing rule files took \x1B[1;32m", format_float(t_diff_ms, ffDecimal, 1), "\x1B[0m ms."

lint_files(@[filename], RULES)

