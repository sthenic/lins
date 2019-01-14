import times
import streams
import sequtils

import ./base_linter
import ../utils/log
import ../rules/plain_rules
import ../parsers/plain_parser

export LinterFileIOError, LinterValueError, LinterParseError, LinterDebugOptions
export open_linter


type PlainLinter* = object of BaseLinter
   parser: PlainParser


proc lint_segment(l: var PlainLinter, seg: PlainTextSegment, rules: seq[Rule]) =
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


# TODO: Think about how best to add line and col initialization values.
proc lint_files*(l: var PlainLinter, file_list: seq[string], rules: seq[Rule],
                 line_init, col_init: int): bool =
   var t_start, t_stop, delta_analysis: float
   result = true

   delta_analysis = 0
   for filename in file_list:
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
      except PlainParseError as e:
         # Catch and reraise the exception with a type local to this module.
         # Callers are not aware of the lexing and parsing process.
         log.abort(LinterParseError,
                   "Parse error when processing file '$1'.", filename)

      delta_analysis += (t_stop - t_start) * 1000.0

      if l.nof_violations_file == (0, 0, 0):
         result = false
         echo "No style errors found."

      inc(l.nof_violations_total, l.nof_violations_file)
      inc(l.nof_files)

   l.print_footer(delta_analysis)


proc lint_string*(l: var PlainLinter, str: string, rules: seq[Rule],
                  line_init, col_init: int): bool =
   var t_start, t_stop: float
   result = true

   let ss = new_string_stream(str)

   l.print_header("String input")
   try:
      var p: PlainParser
      open_parser(p, "stdin", ss)
      t_start = cpu_time()
      for seg in parse_all(p):
         l.lint_segment(seg, rules)
      t_stop = cpu_time()
      close_parser(p)
   except PlainParseError:
      log.abort(LinterParseError,
                "Parse error when processing input from stdin.")

   if l.nof_violations_file == (0, 0, 0):
      result = false
      echo "No style errors found."

   l.print_footer((t_stop - t_start) * 1000.0)
