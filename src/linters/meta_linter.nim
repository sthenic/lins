import streams
import os

import ./linter
import ../utils/log

export LinterFileIOError, LinterValueError, LinterParseError,
       LinterDebugOptions, LintResult

type
   Filter* = enum
      AUTO
      PLAIN
      LATEX

   MetaLinter* = object
      plain_linter: PlainLinter
      latex_linter: LaTeXLinter

      plain_filter: seq[string]
      latex_filter: seq[string]


proc open_linter*(l: var MetaLinter, minimal_mode: bool,
                  severity_threshold: Severity, parser_output_stream: Stream) =
   # Plain linter
   open_linter(l.plain_linter, minimal_mode, severity_threshold,
               parser_output_stream)
   l.plain_filter = @[".txt"]

   # LaTeX linter
   open_linter(l.latex_linter, minimal_mode, severity_threshold,
               parser_output_stream)
   l.latex_filter = @[".tex", ".sty"]


proc print_footer(l: MetaLinter, lint_result: LintResult) =
   let minimal_mode = l.plain_linter.minimal_mode or l.latex_linter.minimal_mode
   print_footer(lint_result, minimal_mode)


proc lint_file(l: var MetaLinter, filename: string, rules: var seq[Rule],
               line_init, col_init: int, use_filter: bool): LintResult =
   result = lint_file(l.plain_linter, filename, rules, line_init, col_init)
   l.print_footer(result)


proc lint_files*(l: var MetaLinter, files: seq[string], rules: var seq[Rule],
                 line_init, col_init: int, filter: Filter): LintResult =
   for filename in files:
      case filter
      of AUTO:
         let (_, _, ext) = split_file(filename)
         if ext in l.latex_filter:
            handle(result, lint_file(l.latex_linter, filename, rules, line_init,
                                     col_init))
         else:
            handle(result, lint_file(l.plain_linter, filename, rules, line_init,
                                     col_init))
      of PLAIN:
         handle(result, lint_file(l.plain_linter, filename, rules, line_init,
                                  col_init))
      of LATEX:
         handle(result, lint_file(l.latex_linter, filename, rules, line_init,
                                  col_init))
   l.print_footer(result)


proc lint_string*(l: var MetaLinter, str: string, rules: var seq[Rule],
                 line_init, col_init: int, filter: Filter): LintResult =
   case filter
   of Plain, Auto:
      result = lint_string(l.plain_linter, str, rules, line_init, col_init)
   of LaTeX:
      result = lint_string(l.latex_linter, str, rules, line_init, col_init)
   l.print_footer(result)
