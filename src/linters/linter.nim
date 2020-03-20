import strutils
import strformat
import streams
import terminal
import nre
import times

import ../utils/log
import ../utils/wordwrap
import ../rules/latex_rules
import ../rules/plain_rules
import ../parsers/plain_parser
import ../parsers/latex_parser

# We export strformat since format() is used in a generic proc. Callers should
# get everything provided when importing this module.
export strformat, Severity, Rule

type
   LinterFileIOError* = object of Exception
   LinterValueError* = object of Exception
   LinterParseError* = object of Exception

   LinterDebugOptions* = tuple
      parser_output_filename: string

   LintResult* = tuple
      delta_analysis: float
      has_violations: bool
      nof_violations: ViolationCount
      nof_files: int

   ViolationCount = tuple
      error: int
      warning: int
      suggestion: int

   Linter*[T] = object
      minimal_mode*: bool
      severity_threshold*: Severity
      parser_output_stream*: Stream
      parser: T

   PlainLinter* = Linter[PlainParser]
   LaTeXLinter* = Linter[LaTeXParser]


proc open_linter*(l: var Linter, minimal_mode: bool,
                  severity_threshold: Severity, parser_output_stream: Stream) =
   l.minimal_mode = minimal_mode
   l.severity_threshold = severity_threshold
   l.parser_output_stream = parser_output_stream


proc inc*(x: var ViolationCount, y: ViolationCount) =
   inc(x.error, y.error)
   inc(x.warning, y.warning)
   inc(x.suggestion, y.suggestion)


proc `+`*(x, y: ViolationCount): ViolationCount =
   result.error = x.error + y.error
   result.warning = x.warning + y.warning
   result.suggestion = x.suggestion + y.suggestion


proc print_violation*(l: Linter, v: Violation) =
   let message = wrap_words(v.message, 48, true).split_lines()

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

   call_styled_write_line(&" l.{v.position.line:<4}  ",
                          styleBright, severity_color, &"{severity_str:<12}",
                          resetStyle, &"{message[0]:<48}    ",
                          styleBright, &"{v.display_name:<20}", resetStyle)

   for m in 1..<len(message):
      let tmp = ""
      call_styled_write_line(&"{tmp:21}{message[m]:<48}")


proc print_header*(l: Linter, str: string) =
   # Suppress headers in minimal mode.
   if l.minimal_mode:
      return

   call_styled_write_line(styleBright, styleUnderscore, &"\n{str}", resetStyle)


proc print_footer*(lint_result: LintResult, minimal_mode: bool) =
   # Suppress footers in minimal mode.
   if minimal_mode:
      return

   call_styled_write_line(styleBright, "\n\nAnalysis completed in ", fgGreen,
                          format_float(lint_result.delta_analysis,
                                       ffDecimal, 1),
                          " ms", resetStyle, styleBright, " with ", resetStyle)

   var file_str = ""
   if lint_result.nof_files == 1:
      file_str = "in 1 file."
   elif lint_result.nof_files > 1:
      file_str = &"in {lint_result.nof_files} files."

   call_styled_write_line(
      styleBright, fgRed,
      &"  {lint_result.nof_violations.error} errors", resetStyle, ", ",
      styleBright, fgYellow,
      &"{lint_result.nof_violations.warning} warnings",  resetStyle, " and ",
      styleBright, fgBlue,
      &"{lint_result.nof_violations.suggestion} suggestions", resetStyle,
      &" {file_str}"
   )


proc lint_segment*[T](l: var Linter, seg: T, rules: var seq[Rule]): ViolationCount =
   var violations: seq[Violation] = @[]

   if not is_nil(l.parser_output_stream):
      # Dump the parser output if the file stream is defined.
      l.parser_output_stream.write_line(seg, "\n")

   for r in mitems(rules):
      # Ignore rules if the log level is set too low.
      if r.severity < l.severity_threshold:
         continue
      add(violations, r.enforce(seg))

   for v in violations:
      case v.severity
      of ERROR:
         inc(result.error)
      of WARNING:
         inc(result.warning)
      of SUGGESTION:
         inc(result.suggestion)

      l.print_violation(v)


proc handle*(x: var LintResult, y: LintResult) =
   x.has_violations = x.has_violations or y.has_violations
   x.delta_analysis += y.delta_analysis
   inc(x.nof_files, y.nof_files)
   inc(x.nof_violations, y.nof_violations)


proc lint_file*(l: var Linter, filename: string, rules: var seq[Rule],
                line_init, col_init: int): LintResult =
   var t_start, t_stop: float
   result.has_violations = true
   result.nof_files = 1

   # Reset per-file variables.
   reset(rules)

   let fs = new_file_stream(filename, fmRead)
   if is_nil(fs):
      log.abort(LinterFileIOError,
               "Failed to open input file '$1' for reading.", filename)

   l.print_header(filename)
   try:
      open_parser(l.parser, filename, fs)
      t_start = cpu_time()
      for seg in parse_all(l.parser):
         inc(result.nof_violations, l.lint_segment(seg, rules))
      t_stop = cpu_time()
      close_parser(l.parser)
   except ParseError:
      # Catch and reraise the exception with a type local to this module.
      # Callers are not aware of the lexing and parsing process.
      log.abort(LinterParseError,
                "Parse error when processing file '$1'.", filename)

   result.delta_analysis = (t_stop - t_start) * 1000.0

   if result.nof_violations == (0, 0, 0):
      result.has_violations = false
      echo "No style errors found."


proc lint_string*(l: var Linter, str: string, rules: var seq[Rule],
                  line_init, col_init: int): LintResult =
   var t_start, t_stop: float
   result.has_violations = true

   let ss = new_string_stream(str)

   l.print_header("String input")
   try:
      open_parser(l.parser, "stdin", ss)
      t_start = cpu_time()
      for seg in parse_all(l.parser):
         inc(result.nof_violations, l.lint_segment(seg, rules))
      t_stop = cpu_time()
      close_parser(l.parser)
   except ParseError:
      log.abort(LinterParseError,
                "Parse error when processing input from stdin.")

   if result.nof_violations == (0, 0, 0):
      result.has_violations = false
      echo "No style errors found."

   result.delta_analysis = (t_stop - t_start) * 1000.0
