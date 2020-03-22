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

var trules: seq[Rule]
let existence_foo_bar = parse_rule_string("""
extends: existence
message: "'$1' left in text."
ignorecase: true
level: warning
nonword: true
tokens:
- foo
- bar""")

# Tests
add(trules, existence_foo_bar)
run_test("Existence, simple", trules,
"""Catch foo if you can. Bar is trying to sneak past too.""", @[
   create_violation(existence_foo_bar, pos(1, 7), "foo"),
   create_violation(existence_foo_bar, pos(1, 23), "Bar")
])
