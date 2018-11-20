import times
import strutils
import strformat
import streams
import terminal
import unicode
import nre
import sequtils

import ../utils/log
import ../rules/plain_rules
import ../parsers/plain_parser


type
   PlainLinterFileIOError* = object of Exception
   PlainLinterValueError* = object of Exception
   PlainLinterParseError* = object of Exception

   ViolationCount = tuple
      error: int
      warning: int
      suggestion: int

   PlainDebugOptions* = tuple
      lexer_output_filename: string


var nof_violations_total: ViolationCount
var nof_violations_file: ViolationCount
var nof_files: int
var lint_rules: seq[Rule]
var minimal_mode = false
var severity_threshold = SUGGESTION
var lexer_output_fs : FileStream


proc set_minimal_mode*(state: bool) =
   ## Enable or disable minimal output mode. This will suppress everything
   ## except the violation messages.
   minimal_mode = state


proc set_severity_threshold*(threshold: Severity) =
   ## Set the severity level. Only violations reaching this level is printed.
   ## For example, WARNING would print both errors and warnings but not
   ## suggestions.
   severity_threshold = threshold


proc split_message(msg: string, limit: int): seq[string] =
   proc helper(s: string): bool =
      result = s != ""

   let regex_break = re("(.{1," & $limit & "})(?:(?<!')|$)(?:\\b|$|(?=_))(?!')")
   result = filter(split(msg, regex_break), helper)
   for i in 0..<result.len:
      result[i] = result[i].strip()


proc print_violation(v: Violation) =
   let message = split_message(v.message, 48)

   var severity_color: ForegroundColor = fgWhite
   var severity_str: string = ""
   case v.severity
   of SUGGESTION:
      severity_str = "suggestion"
      severity_color = fgBlue
   of WARNING:
      severity_str = "warning"
      severity_color = fgYellow
   of ERROR:
      severity_str = "error"
      severity_color = fgRed
   else:
      log.abort(PlainLinterValueError, "Unsupported severity level '$1'.",
                $v.severity)

   call_styled_write_line(&" {v.position.line:>4}:{v.position.col:<5} ",
                          styleBright, severity_color, &"{severity_str:<12}",
                          resetStyle, &"{message[0]:<48}    ",
                          styleBright, &"{v.display_name:<20}", resetStyle)

   for m in 1..<message.len:
      let tmp = ""
      call_styled_write_line(&"{tmp:24}{message[m]:<48}")


proc print_header(str: string) =
   # Suppress headers in minimal mode.
   if minimal_mode:
      return

   call_styled_write_line(styleBright, styleUnderscore, &"\n{str}", resetStyle)


proc print_footer(time_ms: float, violation_count: ViolationCount,
                  nof_files: int) =
   # Suppress footers in minimal mode.
   if minimal_mode:
      return

   call_styled_write_line(styleBright, "\n\nAnalysis completed in ", fgGreen,
                          format_float(time_ms, ffDecimal, 1), " ms",
                          resetStyle, styleBright, " with ", resetStyle)

   var file_str = ""
   if nof_files == 1:
      file_str = "in 1 file."
   elif nof_files > 1:
      file_str = &"in {nof_files} files."

   call_styled_write_line(
      styleBright, fgRed,
      &"  {violation_count.error} errors", resetStyle, ", ",
      styleBright, fgYellow,
      &"{violation_count.warning} warnings",  resetStyle, " and ",
      styleBright, fgBlue,
      &"{violation_count.suggestion} suggestions", resetStyle,
      &" {file_str}"
   )

proc parse_debug_options(debug_options: PlainDebugOptions) =
   if not (debug_options.lexer_output_filename == ""):
      # User has asked for lexer output in a separate file.
      lexer_output_fs = new_file_stream(debug_options.lexer_output_filename,
                                        fmWrite)
      if is_nil(lexer_output_fs):
         log.error("Failed to open file '$1' for writing.",
                   debug_options.lexer_output_filename)
      else:
         log.info("Lexer output will be written to file '$1'.",
                  debug_options.lexer_output_filename)

proc lint_segment(seg: PlainTextSegment) =
   var violations: seq[Violation] = @[]

   if not is_nil(lexer_output_fs):
      # Dump the lexer output if the file stream is defined.
      lexer_output_fs.write_line(seg, "\n")

   for r in lint_rules:
      # Ignore rules if the log level is set too low.
      if r.severity > severity_threshold:
         continue
      violations.add(r.enforce(seg))

   for v in violations:
      case v.severity
      of ERROR:
         nof_violations_file.error += 1
      of WARNING:
         nof_violations_file.warning += 1
      of SUGGESTION:
         nof_violations_file.suggestion += 1
      else:
         discard

      print_violation(v)

# TODO: Think about how best to add line and col initialization values.
proc lint_files*(file_list: seq[string], rules: seq[Rule],
                 line_init, col_init: int,
                 debug_options: PlainDebugOptions): bool =
   var t_start, t_stop, delta_analysis: float
   lint_rules = rules
   result = true

   # Handle debug options.
   parse_debug_options(debug_options)

   delta_analysis = 0
   for filename in file_list:
      nof_violations_file = (0, 0, 0)
      reset(lint_rules)

      # Open the input file as a file stream since we will have to move around
      # in the file.
      var fs = new_file_stream(filename, fmRead)
      if is_nil(fs):
         log.abort(PlainLinterFileIOError,
                   "Failed to open input file '$1' for reading.", filename)

      print_header(filename)

      try:
         var p: PlainParser
         open_parser(p, filename, fs)
         t_start = cpu_time()
         for seg in parse_all(p):
            lint_segment(seg)
         t_stop = cpu_time()
         close_parser(p)
      except PlainParseError as e:
         # Catch and reraise the exception with a type local to this module.
         # Callers are not aware of the lexing and parsing process.
         log.abort(PlainLinterParseError,
                   "Parse error when processing file '$1'.", filename)

      delta_analysis += (t_stop - t_start) * 1000.0

      if (nof_violations_file.error == 0 and
          nof_violations_file.warning == 0 and
          nof_violations_file.suggestion == 0):
         result = false
         echo "No style errors found."

      nof_violations_total.error += nof_violations_file.error
      nof_violations_total.warning += nof_violations_file.warning
      nof_violations_total.suggestion += nof_violations_file.suggestion
      nof_files += 1

   print_footer(delta_analysis, nof_violations_total, nof_files)


proc lint_string*(str: string, rules: seq[Rule], line_init, col_init: int,
                  debug_options: PlainDebugOptions): bool =
   var t_start, t_stop: float
   lint_rules = rules
   result = true

   parse_debug_options(debug_options)

   var ss = new_string_stream(str)

   print_header("String input")

   try:
      var p: PlainParser
      open_parser(p, "stdin", ss)
      t_start = cpu_time()
      for seg in parse_all(p):
         lint_segment(seg)
      t_stop = cpu_time()
      close_parser(p)
   except PlainParseError:
      log.abort(PlainLinterParseError,
                "Parse error when processing input from stdin.")

   if (nof_violations_file.error == 0 and
       nof_violations_file.warning == 0 and
       nof_violations_file.suggestion == 0):
      result = false
      echo "No style errors found."

   print_footer((t_stop - t_start) * 1000.0, nof_violations_file, 0)
