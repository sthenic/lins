import terminal
import strformat
import os
import streams

import ../../src/utils/configuration

# var p: CfgParser
var nof_passed = 0
var nof_failed = 0

template run_test(title, stimuli: string, reference: CfgState, expect_error = false) =
   let ss = new_string_stream(stimuli)
   var passed = false
   var response: CfgState
   try:
      response = parse(ss, ".")
      passed = response == reference
   except CfgParseError as e:
      if expect_error:
         passed = true
      else:
         passed = false
         echo "Exception: '", e.msg, "'"

   if passed:
      styledWriteLine(stdout, styleBright, fgGreen, "[✓] ",
                     fgWhite, "Test '",  title, "'")
      inc(nof_passed)
   else:
      styledWriteLine(stdout, styleBright, fgRed, "[✗] ",
                     fgWhite, "Test '",  title, "'")
      inc(nof_failed)
      echo response
      echo reference


run_test("Empty file", "", CfgState(filename: "."))


run_test("Start w/ a key/value pair.", "foo = bar", CfgState(), true)


run_test("RuleDir: w/o entries", """
[RuleDirs]
""", CfgState(filename: "."))


run_test("RuleDir: w/ entries", """
[RuleDirs]
"/path/to/rules/foo"
baz="/path/to/rules/bar"
"/path/to/rules/fooo/"
""", CfgState(filename: ".", rule_dirs: @[
   CfgRuleDir(name: "foo", path: "/path/to/rules/foo"),
   CfgRuleDir(name: "baz", path: "/path/to/rules/bar"),
   CfgRuleDir(name: "fooo", path: "/path/to/rules/fooo")
]))


run_test("Style w/o name", "[Style]", CfgState(), true)


run_test("Style, simple", """
[Style]
name = foo
rule = bar
""", CfgState(filename: ".", styles: @[
   CfgStyle(name: "foo", is_default: false, rules: @[
      CfgStyleRule(name: "bar")
   ])
]))


run_test("Style w/ default", """
[Style]
name = foo
default = TruE
rule = bar
""", CfgState(filename: ".", styles: @[
   CfgStyle(name: "foo", is_default: true, rules: @[
      CfgStyleRule(name: "bar")
   ])
]))


run_test("Style w/ default, wrong order", """
[Style]
name = foo
rule = bar
default = true
""", CfgState(), true)


run_test("Style w/ except section", """
[Style]
name = foo
rule = bar

[Except]
File1
File2
""", CfgState(filename: ".", styles: @[
   CfgStyle(name: "foo", is_default: false, rules: @[
      CfgStyleRule(
         name: "bar",
         exceptions: @[
            "File1", "File2"
         ]
      )
   ])
]))


run_test("Style w/ only section", """
[Style]
name = foo
rule = bar

[Only]
File3
File23
""", CfgState(filename: ".", styles: @[
   CfgStyle(name: "foo", is_default: false, rules: @[
      CfgStyleRule(
         name: "bar",
         only: @[
            "File3", "File23"
         ]
      )
   ])
]))


run_test("Style w/ except & only", """
[Style]
name = foo
rule = bar

[Except]
Something

[Only]
File3
File23
""", CfgState(), true)


run_test("Two styles", """
[Style]
name = foo
default = true
rule = bar

[Style]
name = secondarystyle
rule = baz
""", CfgState(filename: ".", styles: @[
   CfgStyle(name: "foo", is_default: true, rules: @[
      CfgStyleRule(name: "bar")
   ]),
   CfgStyle(name: "secondarystyle", is_default: false, rules: @[
      CfgStyleRule(name: "baz")
   ])
]))


run_test("Two styles w/ except & only, multiple rules", """
[Style]
name = foo
default = true
rule = bar

[Except]
FooSkip

rule = bar2

[Style]
name = secondarystyle
rule = baz

[Only]
ThisBaz
""", CfgState(filename: ".", styles: @[
   CfgStyle(name: "foo", is_default: true, rules: @[
      CfgStyleRule(
         name: "bar",
         exceptions: @[
            "FooSkip"
         ]
      ),
      CfgStyleRule(name: "bar2")
   ]),
   CfgStyle(name: "secondarystyle", is_default: false, rules: @[
      CfgStyleRule(
         name: "baz",
         only: @[
            "ThisBaz"
         ]
      )
   ])
]))

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
