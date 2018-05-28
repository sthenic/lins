import times
import strutils
import strformat
import parseopt
import tables
import ospaths

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
  file                       Input file to lint. To lint several files, separate
                             them by whitespace.

options:
  -h, --help                 Print this help message and exit.
  -v, --version              Print version and exit.
  --no-cfg                   Don't look for a configuration file.
  --no-default               Don't use a default style (if defined in the
                             configuration file).
  --style=STYLE              Specify which style to use for linting. Styles
                             are defined in the configuration file.
  --rule=RULE                Specify a rule set by name. The rule set will have
                             to be defined in the configuration file.
  --rule-dir=RULE_DIR        Specify a root directory to traverse in search of
                             rule files.
  --lexer {auto,plain-text}  Specify the lexing engine to user. Defaults to
                             'auto', which means that the file extensions are
                             used to infer which lexer to use.
"""



var p = init_opt_parser()
var cli_files: seq[string] = @[]
var cli_rules: seq[string] = @[]
var cli_rule_dirs: seq[string] = @[]
var cli_styles: seq[string] = @[]
var cli_no_cfg = false
var cli_no_default = false
var cli_list = false
var argc = 0

for kind, key, val in p.getopt():
   argc += 1
   case kind:
   of cmdArgument:
      cli_files.add(key)
   of cmdLongOption, cmdShortOption:
      case key:
      of "help", "h":
         echo HELP_TEXT
         quit(0)
      of "version", "v":
         echo VERSION
         quit(0)
      of "no-default":
         cli_no_default = true
      of "no-cfg":
         cli_no_cfg = true
      of "rule":
         cli_rules.add(val)
      of "rule-dir":
         cli_rule_dirs.add(val)
      of "style":
         cli_styles.add(val)
      of "list":
         cli_list = true
      else:
         log.error("Unknown option '$#'.", key)
         quit(-1)
   of cmdEnd:
      assert(false)

if argc == 0:
   echo HELP_TEXT
   quit(-1)

# Build rule database.
var rule_db = init_table[string, seq[Rule]]()
var style_db = init_table[string, seq[Rule]]()
var default_style = ""
let t_start = cpu_time()
block parse_cfg: # TODO: Refactor into a function.
   if cli_no_cfg:
      break parse_cfg

   try:
      let config = parse_cfg_file()

      # Walk through the rule directories specified in the configuration file
      # and build rule objects.
      for dir in config.rule_dirs:
         rule_db[dir.name] = parse_rule_dir(dir.path, NonRecursive)

      # Build styles
      for style in config.styles:
         log.debug("Building rule objects for style '$#'.", style.name)

         style_db[style.name] = @[]
         if style.is_default:
            if (default_style == ""):
               default_style = style.name
            else:
               log.warning("Only one style may be set as the default. " &
                           "Ignoring default specifier for style '$#'.",
                           style.name)

         for rule in style.rules:
            var nof_robj = 0
            # Protect against access violations with undefined keys.
            if not rule_db.has_key(rule.name):
               log.warning("Undefined rule name '$#' in configuration file " &
                           "'$#', skipping.", rule.name, config.filename)
               continue

            if not (rule.exceptions == @[]):
               # Add every rule object except the ones whose source file matches
               # an exception.
               log.debug("Adding rule objects from exceptions.")
               for robj in rule_db[rule.name]:
                  let (_, filename, _) = split_file(robj.source_file)
                  if not (filename in rule.exceptions):
                     style_db[style.name].add(robj)
                     nof_robj += 1

            elif not (rule.only == @[]):
               # Only add rule object whose source file matches an 'only' item.
               for robj in rule_db[rule.name]:
                  let (_, filename, _) = split_file(robj.source_file)
                  if (filename in rule.only):
                     style_db[style.name].add(robj)
                     nof_robj += 1

            else:
               # Add every rule object.
               style_db[style.name].add(rule_db[rule.name])
               nof_robj = rule_db[rule.name].len

            log.debug("  Adding $# rule objects from '$#'.", $nof_robj,
                      rule.name)


   except ConfigurationParseError, ConfigurationPathError, RulePathError:
      discard

# Parse rule directories specified on the command line.
rule_db["cli"] = @[]
if not (cli_rule_dirs == @[]):
   for dir in cli_rule_dirs:
      try:
         rule_db["cli"].add(parse_rule_dir(dir, NonRecursive))
      except RulePathError:
         discard

# Parse named rule sets speficied on the command line.
if not (cli_rules == @[]):
   for rule_name in cli_rules:
      try:
         rule_db["cli"].add(rule_db[rule_name])
      except KeyError:
         log.warning("No definition for rule '$#' found in configuration " &
                     "file, skipping.", rule_name)

let t_diff_ms = (cpu_time() - t_start) * 1000
log.info("Parsing rule files took \x1B[1;32m$#\x1B[0m ms.",
         format_float(t_diff_ms, ffDecimal, 1))


# Construct list of rule objects to use for linting. The rules specified on the
# command line are always included.
var lint_rules = rule_db["cli"]
if not (cli_styles == @[]):
   for style in cli_styles:
      try:
         lint_rules.add(style_db[style])
      except KeyError:
         log.warning("Undefined style '$#'.", style)
elif not cli_no_default and not (default_style == ""):
   # Default style specified.
   log.info("Using default style '$#'.", default_style)
   lint_rules.add(style_db[default_style])


if cli_list:
   echo "\n\x1B[1;4mRule set\x1B[0m"
   var seen: seq[string] = @[]
   for rule in lint_rules:
      if rule.source_file in seen:
         continue
      let (_, filename, _) = split_file(rule.source_file)
      let tmp = &"  \x1B[1m{filename:<20}\x1B[0m"
      echo tmp, rule.source_file

      seen.add(rule.source_file)

   if seen == @[]:
      echo "No rule files."
   quit(0)


if lint_rules == @[]:

   log.error(&"No rules specified.")
   quit(-2)


# Lint files
if not (cli_files == @[]):
   lint_files(cli_files, lint_rules)
else:
   log.error("No input files, stopping.")
