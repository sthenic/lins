import times
import streams
import sequtils

import ./base_linter
import ../utils/log
import ../rules/latex_rules
import ../parsers/latex_parser

export LinterFileIOError, LinterValueError, LinterParseError, LinterDebugOptions
export open_linter


type LaTeXLinter* = object of BaseLinter
   parser: LaTeXParser


proc lint_files*(l: var LaTeXLinter, file_list: seq[string], rules: seq[Rule],
                 line_init, col_init: int): bool =
   base_linter.lint_files(l, file_list, rules, line_init, col_init, result)


proc lint_string*(l: var LaTeXLinter, str: string, rules: seq[Rule],
                  line_init, col_init: int): bool =
   base_linter.lint_string(l, str, rules, line_init, col_init, result)
