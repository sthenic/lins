import times
import strutils
import strformat
import streams
import terminal

import ../lexers/plain_lexer
import ../rules/rules
import ../utils/log

type PlainTextLinterFileIOError* = object of Exception
type PlainTextLinterValueError* = object of Exception

type
   ViolationCount = tuple
      error: int
      warning: int
      suggestion: int

var
   nof_violations_total: ViolationCount
   nof_violations_file: ViolationCount
   nof_files: int
   lint_rules: seq[Rule]
   quiet_mode = false


proc set_quiet_mode*(state: bool) =
   ## Enable or disable quiet output mode. This will suppress everything except
   ## the violation messages.
   quiet_mode = state


proc print_violation(v: Violation) =
   var message: seq[string] = @[]
   for i in countup(0, v.message.len - 1, 48):
      message.add(v.message[i..min(i + 47, v.message.len - 1)])

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
      log.abort(PlainTextLinterValueError, "Unsupported severity level '$#'.",
                $v.severity)

   styled_write_line(stdout, &" {v.position.row:>4}:{v.position.col:<5} ",
                     styleBright, severity_color, &"{severity_str:<11}",
                     resetStyle, &"{message[0]:<48}    ",
                     styleBright, &"{v.source_file:<20}", resetStyle)

   for m in 1..<message.len:
      let tmp = ""
      styled_write_line(stdout, &"{tmp:26}{message[m]:<48}")


proc print_header(str: string) =
   # Suppress headers in quiet mode.
   if quiet_mode:
      return

   styled_write_line(stdout, styleBright, styleUnderscore, &"\n{str}", resetStyle)


proc print_footer(time_ms: float, violation_count: ViolationCount,
                  nof_files: int) =
   # Suppress footers in quiet mode.
   if quiet_mode:
      return

   styled_write_line(stdout, styleBright, "\n\nAnalysis completed in ", fgGreen,
                     format_float(time_ms, ffDecimal, 1), " ms", resetStyle,
                     styleBright, " with ", resetStyle)

   var file_str = ""
   if nof_files == 1:
      file_str = "in 1 file."
   elif nof_files > 1:
      file_str = &"in {nof_files} files."

   styled_write_line(stdout,
                     styleBright, fgRed,
                     &"  {violation_count.error} errors", resetStyle, ", ",
                     styleBright, fgYellow,
                     &"{violation_count.warning} warnings",  resetStyle, " and ",
                     styleBright, fgBlue,
                     &"{violation_count.suggestion} suggestions", resetStyle,
                     &" {file_str}")


proc lint_sentence(s: Sentence) =
   var violations: seq[Violation] = @[]

   for r in lint_rules:
      violations.add(r.enforce(s))

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


proc lint_files*(file_list: seq[string], rules: seq[Rule],
                 row_init, col_init: int): bool =
   var t_start, t_stop, delta_analysis: float
   lint_rules = rules
   result = true

   delta_analysis = 0
   for filename in file_list:
      # Open the input file as a file stream since we will have to move around
      # in the file.
      var fs = new_file_stream(filename, fmRead)
      if is_nil(fs):
         log.abort(PlainTextLinterFileIOError,
                   "Failed to open input file '$#' for reading.", filename)

      print_header(filename)

      try:
         t_start = cpu_time()
         plain_lexer.lex(fs, lint_sentence, row_init, col_init)
         t_stop = cpu_time()
      except PlainTextLexerFileIOError:
         # Catch and reraise the exception with a type local to this module.
         # Callers are not aware of the lexing process.
         raise new_exception(PlainTextLinterFileIOError,
                             "FileIO exception while lexing file.")

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


proc lint_string*(str: string, rules: seq[Rule],
                  row_init, col_init: int): bool =
   var t_start, t_stop: float
   lint_rules = rules
   result = true

   var ss = new_string_stream(str)

   print_header("String input")

   try:
      t_start = cpu_time()
      plain_lexer.lex(ss, lint_sentence, row_init, col_init)
      t_stop = cpu_time()
   except PlainTextLexerFileIOError:
      raise new_exception(PlainTextLinterFileIOError,
                           "FileIO exception while lexing file.")

   if (nof_violations_file.error == 0 and
       nof_violations_file.warning == 0 and
       nof_violations_file.suggestion == 0):
      result = false
      echo "No style errors found."

   print_footer((t_stop - t_start) * 1000.0, nof_violations_file, 0)