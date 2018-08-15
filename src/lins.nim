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
import utils/cli

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

# If the terminal does not have the 'stdout' attribute, i.e. stdout does not
# lead back to the calling terminal, the output is piped to another
# application or written to a file. In any case, disable the colored output and
# do this before parsing the input arguments and options.
if not terminal.isatty(stdout):
   log.set_color_mode(NoColor)

# Parse the arguments and options and return a CLI state object.
var cli_state: CLIState
try:
   cli_state = parse_cli()
except CLIValueError:
   quit(EINVAL)

# Parse CLI object state.
if not cli_state.is_ok:
   # Invalid input combination (but otherwise correctly formatted arguments
   # and options).
   echo HELP_TEXT
   quit(EINVAL)
elif cli_state.print_help:
   # Show help text and exit.
   echo HELP_TEXT
   quit(ESUCCESS)
elif cli_state.print_version:
   # Show version information and exit.
   echo VERSION_STR
   quit(ESUCCESS)

# Propagate CLI state to other modules.
log.set_quiet_mode(cli_state.minimal)
log.set_color_mode(cli_state.color_mode)
plain_linter.set_minimal_mode(cli_state.minimal)
plain_linter.set_severity_threshold(cli_state.severity)

# Build rule database.
var rule_db = init_table[string, seq[Rule]]()
var style_db = init_table[string, seq[Rule]]()
var default_style = ""
let t_start = cpu_time()
if not cli_state.no_cfg: # TODO: Refactor into a function.
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
if not (cli_state.rule_dirs == @[]):
   for dir in cli_state.rule_dirs:
      try:
         rule_db["cli"].add(parse_rule_dir(dir, NonRecursive))
      except RulePathError:
         discard

# Parse named rule sets speficied on the command line.
if not (cli_state.rules == @[]):
   for rule_name in cli_state.rules:
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
if not (cli_state.styles == @[]):
   for style in cli_state.styles:
      try:
         lint_rules.add(style_db[style])
      except KeyError:
         log.warning("Undefined style '$#'.", style)
elif not cli_state.no_default and not (default_style == ""):
   # Default style specified.
   log.info("Using default style '$#'.", default_style)
   lint_rules.add(style_db[default_style])


if cli_state.print_list:
   # List styles.
   call_styled_write_line("\n", styleBright, styleUnderscore,
                          "Styles", resetStyle)

   for style_name, rules in style_db:
      call_styled_write_line(styleBright, &"  {style_name:<15}", resetStyle)
      call_styled_write_line("    ", $len(rules), " rules")

   # List current rule set.
   call_styled_write_line("\n", styleBright, styleUnderscore,
                          "Current rule set", resetStyle)
   var seen: seq[string] = @[]
   for rule in lint_rules:
      if rule.source_file in seen:
         continue
      call_styled_write_line(styleBright, &"  {rule.display_name:<30}",
                             resetStyle, rule.source_file)

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
   lexer_output_filename: cli_state.lexer_output_filename
)

# Lint files
var found_violations: bool
if not (cli_state.files == @[]):
   # If there are any files in the list of input files, run the linter.
   try:
      found_violations = lint_files(cli_state.files, lint_rules,
                                    cli_state.row_init, cli_state.col_init,
                                    debug_options)
   except PlainTextLinterFileIOError:
      quit(EFILE)

elif cli_state.has_arguments:
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
   found_violations = lint_string(text, lint_rules, cli_state.row_init,
                                  cli_state.col_init, debug_options)

if found_violations:
   quit(EVIOL)
else:
   quit(ESUCCESS)
