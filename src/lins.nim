import times
import strutils
import strformat
import parseopt
import tables
import os
import ospaths
import terminal

import linters/plain_linter
import rules/rules
import rules/parser
import utils/log
import utils/cfg

# Version information
const VERSION_STR = static_read("../VERSION").strip()

# Exit codes: negative values are errors.
const EVIOL = 1
const ESUCCESS = 0
const EINVAL = -1
const ENORULES = -2
const EFILE = -3

const STATIC_HELP_TEXT = static_read("help_cli.txt")
let HELP_TEXT = "Lins v" & VERSION_STR & "\n\n" & STATIC_HELP_TEXT

var p = init_opt_parser()
var cli_has_arguments = false
var cli_files: seq[string] = @[]
var cli_rules: seq[string] = @[]
var cli_rule_dirs: seq[string] = @[]
var cli_styles: seq[string] = @[]
var cli_no_cfg = false
var cli_no_default = false
var cli_list = false
var cli_row_init = 1
var cli_col_init = 1
var cli_lexer_output_filename = ""
var argc = 0

# Parse command line options and arguments.
for kind, key, val in p.getopt():
   argc += 1
   case kind:
   of cmdArgument:
      var added_file = false
      cli_has_arguments = true

      for file in walk_files(key):
         log.debug("Adding file '$1'.", file)
         cli_files.add(file)
         added_file = true

      if not added_file:
         log.warning("Failed to find any files matching the pattern '$1'.", key)

   of cmdLongOption, cmdShortOption:
      case key:
      of "help", "h":
         echo HELP_TEXT
         quit(ESUCCESS)
      of "version", "v":
         echo VERSION_STR
         quit(ESUCCESS)
      of "no-default":
         cli_no_default = true
      of "no-cfg":
         cli_no_cfg = true
      of "rule":
         cli_rules.add(val)
      of "rule-dir":
         cli_rule_dirs.add(val)
      of "minimal":
         log.set_quiet_mode(true)
         plain_linter.set_minimal_mode(true)
      of "severity":
         case val.to_lower_ascii()
         of "error":
            plain_linter.set_severity_threshold(ERROR)
         of "warning":
            plain_linter.set_severity_threshold(WARNING)
         of "suggestion":
            plain_linter.set_severity_threshold(SUGGESTION)
         else:
            log.error("Option --severity expects the values 'suggestion', " &
                      "'warning' or 'error'.")
            quit(EINVAL)
      of "style":
         cli_styles.add(val)
      of "list":
         cli_list = true
      of "lexer-output":
         if val == "":
            log.error("Option --lexer-output expects a filename.")
            quit(EINVAL)

         cli_lexer_output_filename = val
      of "row":
         try:
            cli_row_init = parse_int(val)
         except ValueError:
            log.error("Failed to convert '$#' to an integer.", val)
            quit(EINVAL)
      of "col":
         try:
            cli_col_init = parse_int(val)
         except ValueError:
            log.error("Failed to convert '$#' to an integer.", val)
            quit(EINVAL)
      else:
         log.error("Unknown option '$#'.", key)
         quit(EINVAL)
   of cmdEnd:
      assert(false)

# If no file matching patterns have been specified, check if the user has piped
# input to the application. If not, we show the help text and exit.
if (not cli_has_arguments) and terminal.isatty(stdin):
   echo HELP_TEXT
   quit(EINVAL)

# Build rule database.
var rule_db = init_table[string, seq[Rule]]()
var style_db = init_table[string, seq[Rule]]()
var default_style = ""
let t_start = cpu_time()
if not cli_no_cfg: # TODO: Refactor into a function.
   try:
      let config = parse_cfg_file()

      # Walk through the rule directories specified in the configuration file
      # and build rule objects.
      for dir in config.rule_dirs:
         rule_db[dir.name] = parse_rule_dir(dir.path, NonRecursive)

      default_style = get_default_style(config.styles)

      # Build styles
      for style in config.styles:
         log.debug("Building rule objects for style '$#'.", style.name)

         style_db[style.name] = @[]

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


   except ConfigurationFileNotFoundError, ConfigurationParseError,
          ConfigurationPathError, RulePathError:
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
log.info("Parsing rule files took ", fgGreen, styleBright,
         format_float(t_diff_ms, ffDecimal, 1), " ms", resetStyle, ".")


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
   styled_write_line(stdout, "\n", styleBright, styleUnderscore,
                     "Rule set", resetStyle)
   var seen: seq[string] = @[]
   for rule in lint_rules:
      if rule.source_file in seen:
         continue
      let (_, filename, _) = split_file(rule.source_file)
      styled_write_line(stdout, styleBright, &"  {filename:<20}", resetStyle,
                        rule.source_file)

      seen.add(rule.source_file)

   if seen == @[]:
      echo "No rule files."
      quit(ENORULES)
   quit(ESUCCESS)


if lint_rules == @[]:
   log.error("No rules specified.")
   quit(ENORULES)

# Construct debug options
let debug_options: PlainDebugOptions = (
   lexer_output_filename: cli_lexer_output_filename
)

# Lint files
var found_violations: bool
if not (cli_files == @[]):
   # If there are any files in the list of input files, run the linter.
   try:
      found_violations = lint_files(cli_files, lint_rules, cli_row_init,
                                    cli_col_init, debug_options)
   except PlainTextLinterFileIOError:
      quit(EFILE)

elif cli_has_arguments:
   # If the input file list is empty but the user has provided at least one
   # file matching pattern we report an error.
   log.error("No input files, aborting.")
   quit(EINVAL)

else:
   # If the list of input files is empty and the user did not provide any file
   # matching pattern, assume input from stdin.
   log.info("No input files, reading input from ", styleBright, "stdin.",
            resetStyle)
   var text = ""
   var tmp = ""
   while stdin.read_line(tmp):
      text.add(tmp & "\n")
   found_violations = lint_string(text, lint_rules, cli_row_init, cli_col_init,
                                  debug_options)

if found_violations:
   quit(EVIOL)
else:
   quit(ESUCCESS)
