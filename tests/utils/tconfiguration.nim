import terminal
import strformat
import os
import streams

import ../../src/utils/configuration

var p: CfgParser
var nof_passed = 0
var nof_failed = 0

template run_test(title, stimuli: string, reference: CfgState, expect_error = false) =
   let ss = new_string_stream(stimuli)
   var passed = false
   var response: CfgState
   try:
      response = parse(p, ss, ".")
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


run_test("Empty file", "", CfgState())


run_test("Start w/ a key/value pair.", "foo = bar", CfgState(), true)


run_test("RuleDir: w/o entries", """
[RuleDirs]
""", CfgState())


run_test("RuleDir: w/ entries", """
[RuleDirs]
"/path/to/rules/foo"
baz="/path/to/rules/bar"
"/path/to/rules/fooo/"
""", CfgState(rule_dirs: @[
   CfgRuleDir(name: "foo", path: "/path/to/rules/foo"),
   CfgRuleDir(name: "baz", path: "/path/to/rules/bar"),
   CfgRuleDir(name: "fooo", path: "/path/to/rules/fooo")
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
