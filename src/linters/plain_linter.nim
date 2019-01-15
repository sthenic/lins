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


# TODO: Think about how best to add line and col initialization values.
proc lint_files*(l: var PlainLinter, file_list: seq[string], rules: seq[Rule],
                 line_init, col_init: int): bool =
   base_linter.lint_files(l, file_list, rules, line_init, col_init, result)


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
