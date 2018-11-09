import streams
import terminal
import strformat

include ../../src/parsers/latex_parser

var
   response: seq[string] = @[]
   nof_passed = 0
   nof_failed = 0


template run_test(title, stimuli: string; reference: seq[TextSegment]) =
   var response: seq[TextSegment] = @[]
   response = parse_string(stimuli)

   try:
      # for i in 0..<response.len:
      #    echo response[i]
      #    echo reference[i]
      #    do_assert(response[i] == reference[i], "'" & $response[i] & "'")
      # styledWriteLine(stdout, styleBright, fgGreen, "[✓] ",
      #                 fgWhite, "Test '",  title, "'")
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


# Control sequences
run_test("Control word", """Nice!
Cool}\begin{table}%
This is some \emph[a[{t{}hing]{call me}[Maybe][] text.
\end{table}\end{table}[Cool]Do you have something for me?""", @[])


# run_test("Control word",
# """
# Hello \emph{This is some \textbf{cool} emphasized text.} there.""", @[])


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
