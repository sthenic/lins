import times
import strutils
import strformat
import parseopt
import tables
import os
import ospaths
import terminal
import streams

import linters/meta_linter
import rules/rules
import rules/parser
import utils/log
import utils/cfg
import utils/cli

# Version information
const VERSION_STR = static_read("../VERSION").strip()

# Exit codes: negative values are errors.
const ELINTERROR = 3
const ELINTWARNING = 2
const ELINTSUGGESTION = 1
const ESUCCESS = 0
const EINVAL = -1
const ENORULES = -2
const EFILE = -3
const EPARSE = -4

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

# Output the version if the CLI parsing went well.
log.info("Lins v" & VERSION_STR)

# Propagate CLI state to other modules.
log.set_quiet_mode(cli_state.minimal)
log.set_color_mode(cli_state.color_mode)

var parser_output_stream: FileStream
if len(cli_state.parser_output_filename) != 0:
   # User has asked for parser output in a separate file.
   parser_output_stream = new_file_stream(
      cli_state.parser_output_filename, fmWrite)

   if is_nil(parser_output_stream):
      log.error("Failed to open file '$1' for writing.",
                cli_state.parser_output_filename)
   else:
      log.info("Parser output will be written to file '$1'.",
               cli_state.parser_output_filename)

# Create meta linter
var linter = MetaLinter()
open_linter(linter, cli_state.minimal, cli_state.severity,
            parser_output_stream)

# Parse configuration file.
var cfg_state: CfgState
try:
   cfg_state = parse_cfg_file()
except CfgFileNotFoundError, CfgParseError, CfgPathError:
   discard

# Print available styles and the set of active rule files, then exit.
if cli_state.print_list:
   list(cfg_state, cli_state)
   quit(ESUCCESS)

# Build the set of active rule files.
let t_start = cpu_time()
let lint_rules = get_rules(cfg_state, cli_state)
let t_diff_ms = (cpu_time() - t_start) * 1000
log.info("Parsing rule files took ", fgGreen, styleBright,
         format_float(t_diff_ms, ffDecimal, 1), " ms", resetStyle, ".")

if lint_rules == @[]:
   log.error("No rules specified.")
   quit(ENORULES)

# Lint files
var lint_result: LintResult
if not (cli_state.files == @[]):
   # If there are any files in the list of input files, run the linter.
   try:
      lint_result = linter.lint_files(cli_state.files, lint_rules,
                                      cli_state.line_init,
                                      cli_state.col_init,
                                      cli_state.linter)
   except LinterFileIOError:
      quit(EFILE)
   except LinterParseError:
      quit(EPARSE)

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

   try:
      lint_result = linter.lint_string(text, lint_rules,
                                       cli_state.line_init,
                                       cli_state.col_init,
                                       cli_state.linter)
   except LinterParseError:
      quit(EPARSE)

if cli_state.severity_exit:
   if lint_result.nof_violations.error > 0:
      quit(ELINTERROR)
   elif lint_result.nof_violations.warning > 0:
      quit(ELINTWARNING)
   elif lint_result.nof_violations.suggestion > 0:
      quit(ELINTSUGGESTION)
   else:
      quit(ESUCCESS)
else:
   if lint_result.nof_violations.error > 0:
      quit(ELINTERROR)
   else:
      quit(ESUCCESS)
