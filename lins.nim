import times
import strutils
import lexers.plain_text

let t_start = cpu_time()
lex_file("plain_benchmark.txt")
let t_diff_ms = (cpu_time() - t_start) * 1000
echo "Lexing took \x1B[32m", format_float(t_diff_ms, ffDecimal, 1), "\x1B[0m ms."
