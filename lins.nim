import times
import strutils
import parseopt2

import linters.plain_text_linter
import rules.rules
import rules.parser

const VERSION_MAJOR = 0
const VERSION_MINOR = 1
const VERSION_PATCH = 0
let VERSION = $VERSION_MAJOR & "." & $VERSION_MINOR & "." & $VERSION_PATCH

const help_text = """
Usage:

Lins v0.1.0

positional arguments:
  file         Input file to lint

optional arguments:
  -h, --help                 Print this help message and exit.
  -v, --version              Print version and exit.
  --verbose                  Verbose output.
  --rule-dir RULE_DIR        Specify a root directory to traverse in search of
                             rule files.
  --lexer {auto,plain-text}  Specify the lexing engine to user. Defaults to
                             'auto', which means that the file extensions are
                             used to infer which lexer to use.
"""

var p = init_opt_parser()
var files: seq[string] = @[]
var rule_dirs: seq[string] = @[]

for kind, key, val in p.getopt():
   case kind:
   of cmdArgument:
      files.add(key)
   of cmdLongOption, cmdShortOption:
      case key:
      of "help", "h":
         echo help_text
      of "version", "v":
         echo VERSION
      of "rule-dir":
         rule_dirs.add(val)
      else:
         discard
   of cmdEnd:
      assert(false)

echo "Parsing rule directory"
var lrules: seq[Rule] = @[]

let t_start = cpu_time()
for dir in rule_dirs:
   lrules = parse_rule_dir(dir)
let t_diff_ms = (cpu_time() - t_start) * 1000

echo "Parsing rule files took \x1B[1;32m", format_float(t_diff_ms, ffDecimal, 1), "\x1B[0m ms."

if not (files == @[]):
   lint_files(files, lrules)

