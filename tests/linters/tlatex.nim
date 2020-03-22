import streams
import terminal
import strformat

include ../../src/rules/parser
include ../../src/rules/latex_rules
include ../../src/linters/linter

var
   nof_passed = 0
   nof_failed = 0


template run_test(title: string, rules: var seq[Rule], stimuli: string,
                  reference: seq[Violation], debug: bool = false) =
   var response: seq[Violation]
   var l: LaTeXLinter
   let ss = new_string_stream(stimuli)
   open_parser(l.parser, "stdin", ss)

   for seg in parse_all(l.parser):
      for r in mitems(rules):
         add(response, r.enforce(seg))

   try:
      do_assert(len(response) == len(reference))
      for i in 0..<response.len:
         if debug:
            echo response[i]
            echo reference[i]
         do_assert(response[i] == reference[i], "'" & $response[i] & "'")
      styledWriteLine(stdout, styleBright, fgGreen, "[✓] ",
                      fgWhite, "Test '",  title, "'")
      nof_passed += 1
   except AssertionError:
      styledWriteLine(stdout, styleBright, fgRed, "[✗] ",
                      fgWhite, "Test '",  title, "'")
      nof_failed += 1
   except IndexError:
      styledWriteLine(stdout, styleBright, fgRed, "[✗] ",
                      fgWhite, "Test '",  title, "'", #resetStyle,
                      " (missing reference data)")
      nof_failed += 1


proc pos(line: int, col: int): Position =
   result.line = line
   result.col = col

# Tests
var trules: seq[Rule]
let existence_foo_bar = parse_rule_string("""
extends: existence
message: "'$1' left in text."
ignorecase: true
level: warning
tokens:
- foo
- bar""")
add(trules, existence_foo_bar)
run_test("Existence, simple", trules,
"""
Catch foo if you can. Bar is trying to sneak past too.
""", @[
   create_violation(existence_foo_bar, pos(1, 7), "foo"),
   create_violation(existence_foo_bar, pos(1, 23), "Bar")
])


let existence_ignore_case = parse_rule_string("""
extends: existence
message: "'$1' left in text."
ignorecase: false
level: error
tokens:
- fOo
- baR""")
trules = @[existence_ignore_case]
run_test("Existence, simple, case sensitive", trules,
"""
Catch foo Foo FOO fOo if you can. Bar is trying to sneak bar past too baR.
""", @[
   create_violation(existence_ignore_case, pos(1, 19), "fOo"),
   create_violation(existence_ignore_case, pos(1, 71), "baR")
])


let existence_raw = parse_rule_string("""
extends: existence
message: "'$1' is not comparable."
ignorecase: true
level: error
raw:
- \b(?:most|more|less|least|very|extremely)\b\s*
tokens:
- absolute
- adequate
- complete
- unique
- historic""")
trules = @[existence_raw]
run_test("Existence, simple, raw", trules,
"""
Galileio V
----------
Today we have a very unique opportunity to take part, live, in an extremely historic event which...
""", @[
   create_violation(existence_raw, pos(3, 17), "very unique"),
   create_violation(existence_raw, pos(3, 67), "extremely historic")
])


let existence_scope_comment = parse_rule_string("""
extends: existence
message: "Remove '$1'."
ignorecase: false
level: suggestion
scope:
   - comment
tokens:
- TODO
- FIXME""")
trules = @[existence_scope_comment]
run_test("Existence, scope: comment", trules,
"""
Don't trigger on this TODO
% Instead, trigger on this TODO
FIXME: Skip this
% FIXME: Sound the alarm!
""", @[
   create_violation(existence_scope_comment, pos(2, 26), "TODO"),
   create_violation(existence_scope_comment, pos(4, 1), "FIXME")
])


let existence_scope_title = parse_rule_string("""
extends: existence
message: "Remove '$1'."
ignorecase: true
level: suggestion
scope:
   - title
tokens:
- foo""")
trules = @[existence_scope_title]
run_test("Existence, scope: title", trules,
"""
\section{foo}
This section explains the origins of 'foo'.

\subsection{foo}
We need to go deeper to explain the origins of 'foo'.

\subsubsection{foo}
We need to go even deeper to explain the origins of 'foo'.
""", @[
   create_violation(existence_scope_title, pos(1, 1), "foo"),
   create_violation(existence_scope_title, pos(4, 1), "foo"),
   create_violation(existence_scope_title, pos(7, 1), "foo")
])
