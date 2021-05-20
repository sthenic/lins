import streams
import terminal
import strformat

include ../../src/parsers/rule_parser
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
      for i in 0..<response.len:
         if debug:
            echo response[i]
            echo reference[i]
         do_assert(response[i] == reference[i], "'" & $response[i] & "'")
      styledWriteLine(stdout, styleBright, fgGreen, "[✓] ",
                      fgWhite, "Test '",  title, "'")
      nof_passed += 1
   except AssertionDefect:
      echo "Full response:"
      for r in response:
         echo r
      styledWriteLine(stdout, styleBright, fgRed, "[✗] ",
                      fgWhite, "Test '",  title, "'")
      nof_failed += 1
   except IndexDefect:
      styledWriteLine(stdout, styleBright, fgRed, "[✗] ",
                      fgWhite, "Test '",  title, "'",
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
trules = @[existence_foo_bar]
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


let existence_scope_math = parse_rule_string("""
extends: existence
message: "Remove '$1'."
ignorecase: true
level: suggestion
nonword: true
scope:
- math
tokens:
- foo""")
trules = @[existence_scope_math]
run_test("Existence, scope: math", trules,
"""
Foo in inline math:
$foo(x)$
\(x(foo)\)

Foo in displayed math:
$$foo(x)$$
\[foo(y)\]

Foo in equations:
\begin{equation}
\sum_{k=0}^\infty foo_k
\end{equation}

\begin{equation*}
\sum_{k=0}^\infty foo_k
\end{equation*}

""", @[
   create_violation(existence_scope_math, pos(2, 1), "foo"),
   create_violation(existence_scope_math, pos(3, 3), "foo"),
   create_violation(existence_scope_math, pos(6, 1), "foo"),
   create_violation(existence_scope_math, pos(7, 1), "foo"),
   create_violation(existence_scope_math, pos(11, 6), "foo"),
   create_violation(existence_scope_math, pos(15, 6), "foo")
])


let existence_scope_text = parse_rule_string("""
extends: existence
message: "Remove '$1'."
ignorecase: true
level: suggestion
nonword: true
scope:
- text
tokens:
- foo""")
trules = @[existence_scope_text]
run_test("Existence, scope: text", trules,
"""
Don't trigger on this foo.
\begin{document}
Trigger on this foo.
\end{document}
""", @[
   create_violation(existence_scope_text, pos(3, 17), "foo")
])


let existence_exceptions = parse_rule_string("""
extends: existence
message: "Remove '$1'."
ignorecase: false
level: suggestion
nonword: false
tokens:
- '[A-Z]{3,}'
exceptions:
- CDE""")
trules = @[existence_exceptions]
run_test("Existence, regex w/ exceptions", trules,
"""
The groups ABC, CDE and EFG are what you get if you split the first nine letters
of the alphabet into groups of three letters each.
""", @[
   create_violation(existence_exceptions, pos(1, 12), "ABC"),
   create_violation(existence_exceptions, pos(1, 25), "EFG")
])


let existence_latex_scopes = parse_rule_string("""
extends: existence
message: "Remove '$1'."
ignorecase: false
level: warning
latex:
  - name: foo
    type: control sequence
    leading: required\s$
  - name: bar
    type: environment
    logic: and
  - name: baz
    type: control sequence
    logic: and
tokens:
- here
- this""")
trules = @[existence_latex_scopes]
run_test("Existence, LaTeX scopes (AND and OR)", trules,
"""
Some introductory text is required \foo{to cause the rule to be
enforced in here}{and here too} but \foo{the rule is not enforced
in here}.

The rule will \baz{not be enforced here}
\begin{bar}
and not here either.
\baz{However, this text will be targeted by the rule.}
\end{bar}
""", @[
   create_violation(existence_latex_scopes, pos(2, 13), "here"),
   create_violation(existence_latex_scopes, pos(2, 5), "here"),
   create_violation(existence_latex_scopes, pos(8, 10), "this")
])


let existence_latex_scope_not = parse_rule_string("""
extends: existence
message: "Remove '$1'."
ignorecase: false
level: warning
latex:
  - name: foo
    type: control sequence
  - name: bar
    type: control sequence
    logic: not
tokens:
- here""")
trules = @[existence_latex_scope_not]
run_test("Existence, LaTeX scopes (NOT)", trules,
"""
Check for \foo{violations in here but not \bar{in here}}
""", @[
   create_violation(existence_latex_scope_not, pos(1, 15), "here"),
])


let existence_latex_scope_descend = parse_rule_string("""
extends: existence
message: "A caption should be more than five words."
ignorecase: true
nonword: true
level: warning
latex:
  - name: caption
    type: control sequence
    descend: false
tokens:
- ^(\s*\b[\w']+\.?){0,5}$""")
trules = @[existence_latex_scope_descend]
run_test("Existence, LaTeX descend", trules,
"""
\caption{Fewer than five words.}
\caption{This contains exactly five words.}
\caption{This is more than five words.}
\caption{This is more than five words \foo{but this isn't}.}
""", @[
   create_violation(existence_latex_scope_descend, pos(1, 1)),
   create_violation(existence_latex_scope_descend, pos(2, 1)),
])


let existence_latex_invert = parse_rule_string("""
extends: existence
message: "A \foo sequence should always contain 'hello'."
ignorecase: true
level: warning
invert: true
latex:
  - name: foo
    type: control sequence
tokens:
- hello""")
trules = @[existence_latex_invert]
run_test("Existence, LaTeX invert", trules,
"""
This is wrong: \foo{a}.

This is correct: \foo{hello}.
""", @[
   create_violation(existence_latex_invert, pos(1, 1)),
])

# Print summary
styledWriteLine(stdout, styleBright, "\n----- SUMMARY -----")
var test_str = "test"
if nof_passed == 1:
   test_str.add(' ')
else:
   test_str.add('s')
styledWriteLine(stdout, styleBright, &" {$nof_passed:<4} ", test_str,
                fgGreen, " PASSED")

test_str = "test"
if nof_failed == 1:
   test_str.add(' ')
else:
   test_str.add('s')
styledWriteLine(stdout, styleBright, &" {$nof_failed:<4} ", test_str,
                fgRed, " FAILED")

styledWriteLine(stdout, styleBright, "-------------------")

quit(nof_failed)
