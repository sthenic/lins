import strutils
import strformat
import streams
import terminal
import nre
import sequtils

import ../utils/log
import ../rules/rules
import ../parsers/base_parser


type
   LinterFileIOError* = object of Exception
   LinterValueError* = object of Exception
   LinterParseError* = object of Exception

   LinterDebugOptions* = tuple
      parser_output_filename: string

   ViolationCount = tuple
      error: int
      warning: int
      suggestion: int

   BaseLinter* = object of RootObj
      nof_violations_total*: ViolationCount
      nof_violations_file*: ViolationCount
      nof_files*: int
      minimal_mode*: bool
      severity_threshold*: Severity
      parser_output_stream*: Stream


proc open_linter*(l: var BaseLinter, minimal_mode: bool,
                  severity_threshold: Severity, parser_output_stream: Stream) =
   l.minimal_mode = minimal_mode
   l.severity_threshold = severity_threshold
   l.parser_output_stream = parser_output_stream


proc inc*(x: var ViolationCount, y: ViolationCount) =
   inc(x.error, y.error)
   inc(x.warning, y.warning)
   inc(x.suggestion, y.suggestion)


proc split_message(msg: string, limit: int): seq[string] =
   proc helper(s: string): bool =
      result = s != ""

   let regex_break = re("(.{1," & $limit & "})(?:(?<!')|$)(?:\\b|$|(?=_))(?!')")
   result = filter(split(msg, regex_break), helper)
   for i in 0..<result.len:
      result[i] = result[i].strip()


proc print_violation*(l: BaseLinter, v: Violation) =
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
      log.abort(LinterValueError, "Unsupported severity level '$1'.",
                $v.severity)

   call_styled_write_line(&" l.{v.position.line:<4}  ",
                          styleBright, severity_color, &"{severity_str:<12}",
                          resetStyle, &"{message[0]:<48}    ",
                          styleBright, &"{v.display_name:<20}", resetStyle)

   for m in 1..<message.len:
      let tmp = ""
      call_styled_write_line(&"{tmp:21}{message[m]:<48}")


proc print_header*(l: BaseLinter, str: string) =
   # Suppress headers in minimal mode.
   if l.minimal_mode:
      return

   call_styled_write_line(styleBright, styleUnderscore, &"\n{str}", resetStyle)


proc print_footer*(l: BaseLinter, time_ms: float) =
   # Suppress footers in minimal mode.
   if l.minimal_mode:
      return

   call_styled_write_line(styleBright, "\n\nAnalysis completed in ", fgGreen,
                          format_float(time_ms, ffDecimal, 1), " ms",
                          resetStyle, styleBright, " with ", resetStyle)

   var file_str = ""
   if l.nof_files == 1:
      file_str = "in 1 file."
   elif l.nof_files > 1:
      file_str = &"in {l.nof_files} files."

   call_styled_write_line(
      styleBright, fgRed,
      &"  {l.nof_violations_total.error} errors", resetStyle, ", ",
      styleBright, fgYellow,
      &"{l.nof_violations_total.warning} warnings",  resetStyle, " and ",
      styleBright, fgBlue,
      &"{l.nof_violations_total.suggestion} suggestions", resetStyle,
      &" {file_str}"
   )
