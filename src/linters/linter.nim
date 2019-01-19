import strutils
import strformat
import streams
import terminal
import nre
import sequtils
import unicode
import times
import typetraits

import ../utils/log
import ../rules/rules
import ../parsers/plain_parser
import ../parsers/latex_parser

# We export strformat since format() is used in a generic proc. Callers should
# get everything provided when importing this module.
export strformat, rules

type
   LinterFileIOError* = object of Exception
   LinterValueError* = object of Exception
   LinterParseError* = object of Exception

   LinterDebugOptions* = tuple
      parser_output_filename: string

   LintResult* = tuple
      delta_analysis: float
      has_violations: bool

   ViolationCount = tuple
      error: int
      warning: int
      suggestion: int

   Linter*[T] = object
      nof_violations_total*: ViolationCount
      nof_violations_file*: ViolationCount
      nof_files*: int
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


# Borrowed/improved word wrapping implementation from Nim/devel until these are
# released in a compatible state (or not).
type WordWrapState = enum
   AfterNewline
   MiddleOfLine


proc olen(s: string): int =
   var i = 0
   while i < len(s):
      inc(result)
      let L = grapheme_len(s, i)
      inc(i, L)


proc wrap_words*(s: string, max_line_width = 80, split_long_words = true,
                 seps: set[char] = Whitespace,
                 new_line = "\n"): string {.noSideEffect.} =
   ## Word wraps `s`.
   result = new_string_of_cap(len(s) + len(s) shr 6)
   var state: WordWrapState
   var space_rem = max_line_width
   var last_sep, indent = ""
   for word, is_sep in tokenize(s, seps):
      let wlen = olen(word)
      if is_sep:
         # Process the whitespace 'word', adding newlines as needed and keeping
         # any trailing non-newline whitespace characters as the indentation
         # level.
         for c in word:
            if c in NewLines:
               add(result, new_line)
               last_sep.set_len(0)
               indent.set_len(0)
               space_rem = max_line_width
               state = AfterNewline
            else:
               case state
               of AfterNewline:
                  add(indent, c)
                  space_rem = max_line_width - len(indent)
               of MiddleOfLine:
                  add(last_sep, c)
                  dec(space_rem) # TODO: Treat tabs differently?
      elif wlen > space_rem:
         if split_long_words and wlen > max_line_width - len(indent):
            case state
            of AfterNewline:
               result.add(indent)
            of MiddleOfLine:
               result.add(last_sep)
               last_sep.set_len(0)

            var i = 0
            while i < len(word): # TODO: Is len(word) correct here?
               if space_rem <= 0:
                  space_rem = max_line_width - len(indent)
                  result.add(new_line & indent)
               dec(space_rem)
               let L = grapheme_len(word, i)
               for j in 0..<L:
                  result.add(word[i+j])
               inc(i, L)
         else:
            space_rem = max_line_width - len(indent) - len(word)
            result.add(new_line & indent & word)
            last_sep.set_len(0)

         # TODO: Is this ok in the case when the word get broken to exactly 80 chars?
         state = MiddleOfLine
      else:
         # TODO: Think about what happens to space_rem if AfterNewLine. Is it
         # already decremented with the indent level?
         case state
         of AfterNewline:
            result.add(indent)
         of MiddleOfLine:
            result.add(last_sep)
            last_sep.set_len(0)

         space_rem = space_rem - len(word)
         result.add(word)
         state = MiddleOfLine


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
   else:
      log.abort(LinterValueError, "Unsupported severity level '$1'.",
                $v.severity)

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


proc print_footer*(l: Linter, time_ms: float) =
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


proc lint_segment*[T](l: var Linter, seg: T, rules: seq[Rule]) =
   var violations: seq[Violation] = @[]

   if not is_nil(l.parser_output_stream):
      # Dump the parser output if the file stream is defined.
      l.parser_output_stream.write_line(seg, "\n")

   for r in rules:
      # Ignore rules if the log level is set too low.
      if r.severity < l.severity_threshold:
         continue
      add(violations, r.enforce(seg))

   for v in violations:
      case v.severity
      of ERROR:
         inc(l.nof_violations_file.error)
      of WARNING:
         inc(l.nof_violations_file.warning)
      of SUGGESTION:
         inc(l.nof_violations_file.suggestion)
      else:
         discard

      l.print_violation(v)


proc handle*(x: var LintResult, y: LintResult) =
   x.has_violations = x.has_violations or y.has_violations
   x.delta_analysis += y.delta_analysis


proc lint_file*(l: var Linter, filename: string, rules: seq[Rule],
                line_init, col_init: int): LintResult =
   var t_start, t_stop: float
   result.has_violations = true

   # Reset per-file variables.
   l.nof_violations_file = (0, 0, 0)
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
         l.lint_segment(seg, rules)
      t_stop = cpu_time()
      close_parser(l.parser)
   except ParseError:
      # Catch and reraise the exception with a type local to this module.
      # Callers are not aware of the lexing and parsing process.
      log.abort(LinterParseError,
               "Parse error when processing file '$1'.", filename)

   result.delta_analysis = (t_stop - t_start) * 1000.0

   if l.nof_violations_file == (0, 0, 0):
      result.has_violations = false
      echo "No style errors found."

   inc(l.nof_violations_total, l.nof_violations_file)
   inc(l.nof_files)


proc lint_string*(l: var Linter, str: string, rules: seq[Rule],
                  line_init, col_init: int): LintResult =
   var t_start, t_stop: float
   result.has_violations = true

   let ss = new_string_stream(str)

   l.print_header("String input")
   try:
      open_parser(l.parser, "stdin", ss)
      t_start = cpu_time()
      for seg in parse_all(l.parser):
         l.lint_segment(seg, rules)
      t_stop = cpu_time()
      close_parser(l.parser)
   except ParseError:
      log.abort(LinterParseError,
                "Parse error when processing input from stdin.")

   if l.nof_violations_file == (0, 0, 0):
      result.has_violations = false
      echo "No style errors found."

   result.delta_analysis = (t_stop - t_start) * 1000.0
