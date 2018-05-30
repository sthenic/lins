import times
import strutils
import strformat
import streams

import ../lexers/plain_text_lexer
import ../rules/rules
import ../utils/log

type PlainTextLinterFileIOError* = object of Exception

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

   echo &" {v.position.row:>4}:{v.position.col:<5} {v.severity_str:<24} ",
        &"{message[0]:<48}    \x1B[1m{v.source_file:<20}\x1B[0m"

   for m in 1..<message.len:
      let tmp = ""
      echo &"{tmp:26}{message[m]:<48}"


proc print_header(str: string) =
   # Suppress headers in quiet mode.
   if quiet_mode:
      return

   echo &"\n\x1B[1;4m{str}\x1B[0m"


proc print_footer(time_ms: float, violation_count: ViolationCount,
                  nof_files: int) =
   # Suppress footers in quiet mode.
   if quiet_mode:
      return

   echo &"\n\n\x1B[1mAnalysis completed in \x1B[1;32m",
        format_float(time_ms, ffDecimal, 1), &" ms\x1B[0;1m with \x1B[0m"

   var file_str = ""
   if nof_files == 1:
      file_str = "in 1 file."
   elif nof_files > 1:
      file_str = &"in {nof_files} files."

   echo &"  \x1B[1;31m{violation_count.error} errors\x1B[0m, ",
        &"\x1B[1;33m{violation_count.warning} warnings\x1B[0m and ",
        &"\x1B[1;34m{violation_count.suggestion} suggestions\x1B[0m ",
        &"{file_str}"


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


proc lint_files*(file_list: seq[string], rules: seq[Rule]): bool =
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
         plain_text_lexer.lex(fs, lint_sentence)
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


proc lint_string*(str: string, rules: seq[Rule]): bool =
   var t_start, t_stop: float
   lint_rules = rules
   result = true

   var ss = new_string_stream(str)

   print_header("String input")

   try:
      t_start = cpu_time()
      plain_text_lexer.lex(ss, lint_sentence)
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
