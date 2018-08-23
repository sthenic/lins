import terminal
import parseopt
import strutils
import os
import ospaths

import ./log
import ../rules/rules

type CLIValueError* = object of Exception

type CLIState* = object
   has_arguments*: bool
   input_from_stdin*: bool
   is_ok*: bool
   print_help*: bool
   print_version*: bool
   print_list*: bool
   no_cfg*: bool
   no_default*: bool
   color_mode*: ColorMode
   severity*: Severity
   minimal*: bool

   files*: seq[string]
   rules*: seq[string]
   rule_dirs*: seq[string]
   styles*: seq[string]
   row_init*: int
   col_init*: int

   lexer_output_filename*: string

# CLI constructor, initializes an object with default values.
proc new(t: typedesc[CLIState]): CLIState =
   result = CLIState(has_arguments: false,
                     input_from_stdin: false,
                     is_ok: false,
                     print_help: false,
                     print_version: false,
                     print_list: false,
                     no_cfg: false,
                     no_default: false,
                     color_mode: Color,
                     severity: SUGGESTION,
                     minimal: false,
                     files: @[],
                     rules: @[],
                     rule_dirs: @[],
                     styles: @[],
                     row_init: 1,
                     col_init: 1,
                     lexer_output_filename: "")


proc parse_cli*(): CLIState =
   result = CLIState.new()
   if not terminal.isatty(stdout):
      result.color_mode = NoColor

   var p = init_opt_parser()
   for kind, key, val in p.getopt():
      case kind:
      of cmdArgument:
         var added_file = false
         result.has_arguments = true
         result.is_ok = true

         for file in walk_files(key):
            result.files.add(file)
            added_file = true

         if not added_file:
            log.warning("Failed to find any files matching the " &
                        "pattern '$1'.", key)

      of cmdLongOption, cmdShortOption:
         case key:
         of "help", "h":
            result.print_help = true
            result.is_ok = true
         of "version", "v":
            result.print_version = true
            result.is_ok = true
         of "no-default":
            result.no_default = true
         of "no-cfg":
            result.no_cfg = true
         of "rule":
            if val == "":
               log.abort(CLIValueError, "Option --rule expects a value.")

            result.rules.add(val)
         of "rule-dir":
            if val == "":
               log.abort(CLIValueError, "Option --rule-dir expects a value.")

            result.rule_dirs.add(val)
         of "minimal":
            result.minimal = true
         of "no-color":
            result.color_mode = NoColor
         of "severity":
            case val.to_lower_ascii()
            of "error":
               result.severity = ERROR
            of "warning":
               result.severity = WARNING
            of "suggestion":
               result.severity = SUGGESTION
            else:
               log.abort(CLIValueError, "Option --severity expects the " &
                         "values 'suggestion', 'warning' or 'error'.")
         of "style":
            if val == "":
               log.abort(CLIValueError, "Option --style expects a value.")

            result.styles.add(val)
         of "list":
            result.print_list = true
            result.is_ok = true
         of "lexer-output":
            if val == "":
               log.abort(CLIValueError,
                         "Option --lexer-output expects a filename.")

            result.lexer_output_filename = val
         of "row":
            if val == "":
               log.abort(CLIValueError, "Option --row expects a value.")

            try:
               result.row_init = parse_int(val)
            except ValueError:
               log.abort(CLIValueError,
                         "Failed to convert '$1' to an integer.", val)
         of "col":
            if val == "":
               log.abort(CLIValueError, "Option --row expects a value.")

            try:
               result.col_init = parse_int(val)
            except ValueError:
               log.abort(CLIValueError,
                         "Failed to convert '$1' to an integer.", val)
         else:
            log.abort(CLIValueError, "Unknown option '$1'.", key)

      of cmdEnd:
         log.abort(CLIValueError, "Failed to parse options and arguments " &
                  "This should not have happened.")

   # Check if the user has piped input to the application (the terminal will
   # not have the 'stdin' attribute set). If so, this is also a valid CLI
   # state
   if not terminal.isatty(stdin):
      result.input_from_stdin = true
      result.is_ok = true