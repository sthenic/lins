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
   base_linter.lint_string(l, str, rules, line_init, col_init, result)
