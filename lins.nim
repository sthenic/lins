import times
import strutils
import strformat
import parseopt

import linters.plain_text_linter
import rules.rules
import rules.parser
import utils.log
import utils.cfg

const VERSION_MAJOR = 0
const VERSION_MINOR = 1
const VERSION_PATCH = 0
let VERSION = $VERSION_MAJOR & "." & $VERSION_MINOR & "." & $VERSION_PATCH

const HELP_TEXT = """
Lins v0.1.0

arguments:
  file         Input file to lint

options:
  -h, --help                 Print this help message and exit.
  -v, --version              Print version and exit.
  --rule-dir RULE_DIR        Specify a root directory to traverse in search of
                             rule files.
  --lexer {auto,plain-text}  Specify the lexing engine to user. Defaults to
                             'auto', which means that the file extensions are
                             used to infer which lexer to use.
"""



var p = init_opt_parser()
var files: seq[string] = @[]
var rule_dirs: seq[string] = @[]
var argc = 0

for kind, key, val in p.getopt():
   argc += 1
   case kind:
   of cmdArgument:
      files.add(key)
   of cmdLongOption, cmdShortOption:
      case key:
      of "help", "h":
         echo HELP_TEXT
         quit(0)
      of "version", "v":
         echo VERSION
         quit(0)
      of "rule-dir":
         rule_dirs.add(val)
      else:
         log.error("Unknown option '$#'.", key)
         quit(-1)
   of cmdEnd:
      assert(false)

if argc == 0:
   echo HELP_TEXT
   quit(-1)

parse_cfg_file()

# Parse rule set
var lint_rules: seq[Rule] = @[]
if not (rule_dirs == @[]):
   let t_start = cpu_time()
   for dir in rule_dirs:
      log.info("Parsing rule directory '$#'.", dir)
      lint_rules = parse_rule_dir(dir)
   let t_diff_ms = (cpu_time() - t_start) * 1000

   log.info("Parsing rule files took \x1B[1;32m$#\x1B[0m ms.",
            format_float(t_diff_ms, ffDecimal, 1))


# Lint files
if not (files == @[]):
   lint_files(files, lint_rules)
else:
   log.error("No input files, stopping.")
