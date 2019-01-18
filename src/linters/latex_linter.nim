import times

import ./base_linter
import ../utils/log
import ../rules/latex_rules
import ../parsers/latex_parser

export LinterFileIOError, LinterValueError, LinterParseError, LinterDebugOptions,
       LintResult
export open_linter


type LaTeXLinter* = object of BaseLinter
   parser: LaTeXParser


proc lint_file*(l: var LaTeXLinter, filename: string, rules: seq[Rule],
                line_init, col_init: int): LintResult =
   base_linter.lint_file(l, filename, rules, line_init, col_init, result)


proc lint_string*(l: var LaTeXLinter, str: string, rules: seq[Rule],
                  line_init, col_init: int): LintResult =
   base_linter.lint_string(l, str, rules, line_init, col_init, result)
