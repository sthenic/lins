import times

import ./base_linter
import ../utils/log
import ../rules/plain_rules
import ../parsers/plain_parser

export LinterFileIOError, LinterValueError, LinterParseError, LinterDebugOptions,
       LintResult
export open_linter


type PlainLinter* = object of BaseLinter
   parser: PlainParser


# TODO: Think about how best to add line and col initialization values.
proc lint_file*(l: var PlainLinter, filename: string, rules: seq[Rule],
                line_init, col_init: int): LintResult =
   base_linter.lint_file(l, filename, rules, line_init, col_init, result)


proc lint_string*(l: var PlainLinter, str: string, rules: seq[Rule],
                  line_init, col_init: int): LintResult =
   base_linter.lint_string(l, str, rules, line_init, col_init, result)
