import tables
import streams
import ospaths

import ../utils/log
import ../rules/rules
import ./base_linter
import ./plain_linter
import ./latex_linter

export LinterFileIOError, LinterValueError, LinterParseError, LinterDebugOptions,
       LintResult

type
   Filter* = enum
      Auto
      Plain
      LaTeX

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


proc lint_file(l: var MetaLinter, filename: string, rules: seq[Rule],
               line_init, col_init: int, use_filter: bool): LintResult =
   result = lint_file(l.plain_linter, filename, rules, line_init, col_init)
   l.plain_linter.print_footer(result.delta_analysis)


proc lint_files*(l: var MetaLinter, files: seq[string], rules: seq[Rule],
                 line_init, col_init: int, filter: Filter): LintResult =
   for filename in files:
      handle(result, lint_file(l.plain_linter, filename, rules, line_init,
                               col_init))
   l.plain_linter.print_footer(result.delta_analysis)


proc lint_string*(l: var MetaLinter, str: string, rules: seq[Rule],
                 line_init, col_init: int, filter: Filter): LintResult =
   result = lint_string(l.plain_linter, str, rules, line_init, col_init)
   l.plain_linter.print_footer(result.delta_analysis)
