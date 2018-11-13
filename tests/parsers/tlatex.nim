import streams
import terminal
import strformat

include ../../src/parsers/latex_parser

var
   nof_passed = 0
   nof_failed = 0


template run_test(title, stimuli: string; reference: seq[TextSegment]) =
   var response: seq[TextSegment] = @[]
   response = parse_string(stimuli)
   try:
      for i in 0..<response.len:
         # echo response[i]
         # echo reference[i]
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


run_test("Simple sentence",
"""A simple sentence.""", @[
   TextSegment.new("A simple sentence.", 1, 0, @[], @[])
])


run_test("Multiline sentence",
"""A sentence spanning
several lines
of text.""", @[
   TextSegment.new(
      "A sentence spanning several lines of text.", 1, 0,
      @[(20, 2), (34, 3)], @[])
])


run_test("Multiline sentence, irregular spacing",
"""   A sentence  spanning
  several   lines
 of
text.""", @[
   TextSegment.new(
      "A sentence spanning several lines of text.", 1, 3,
      @[(20, 2), (34, 3), (37, 4)], @[])
])


# (La)TeX constructions

run_test("Group w/o control sequence",
"""That's a {\bfseries bold} statement.""", @[
   TextSegment.new(
      """That's a bold statement.""", 1, 0, @[], @[])
])


run_test("Option delimiters w/o control sequence",
"""That's a [\bfseries bold] statement.""", @[
   TextSegment.new(
      """That's a [bold] statement.""", 1, 0, @[], @[])
])


run_test("Control sequence in text, removed",
"""A sentence \foo with a control sequence.""", @[
   TextSegment.new(
      """A sentence with a control sequence.""", 1, 0, @[], @[])
])

run_test("Control sequence in text, expanded",
"""A sentence with \emph{emphasized} text.""", @[
   TextSegment.new(
      """A sentence with emphasized text.""", 1, 0, @[], @[])
])


run_test("Control sequence followed by a group",
"""A sentence with \foo{grouped text} another control sequence.""", @[
   TextSegment.new(
      """grouped text""", 1, 21, @[], @[
         ScopeEntry.new("foo", ControlSequence, Group, 1)
      ]),
   TextSegment.new(
      """A sentence with  another control sequence.""", 1, 0, @[], @[]),
])


run_test("Control sequence followed by options",
"""Another sentence with \bar[option text in here]a few options.""", @[
   TextSegment.new(
      """option text in here""", 1, 27, @[], @[
         ScopeEntry.new("bar", ControlSequence, Option, 1)
      ]),
   TextSegment.new(
      """Another sentence with a few options.""", 1, 0, @[], @[]),
])


run_test("Control sequence followed by options and groups",
"""Text before \mycontrolseq[options here]{first group}{second group}.""", @[
   TextSegment.new(
      """options here""", 1, 26, @[], @[
         ScopeEntry.new("mycontrolseq", ControlSequence, Option, 1)
      ]),
   TextSegment.new(
      """first group""", 1, 40, @[], @[
         ScopeEntry.new("mycontrolseq", ControlSequence, Group, 2)
      ]),
   TextSegment.new(
      """second group""", 1, 53, @[], @[
         ScopeEntry.new("mycontrolseq", ControlSequence, Group, 3)
      ]),
   TextSegment.new(
      """Text before .""", 1, 0, @[], @[]),
])


run_test("Nested control sequences",
"""\foo{And some \bar{with some} extra} \baz{added for effect}.""", @[
   TextSegment.new(
      """with some""", 1, 19, @[], @[
         ScopeEntry.new("foo", ControlSequence, Group, 1),
         ScopeEntry.new("bar", ControlSequence, Group, 1)
      ]),
   TextSegment.new(
      """And some  extra""", 1, 5, @[], @[
         ScopeEntry.new("foo", ControlSequence, Group, 1)
      ]),
   TextSegment.new(
      """added for effect""", 1, 42, @[], @[
         ScopeEntry.new("baz", ControlSequence, Group, 1)
      ]),
   TextSegment.new(
      """ .""", 1, 36, @[], @[]),
])


run_test("Uncaptured group nested in control sequence capture group",
"""\foo{And {some} text}""", @[
   TextSegment.new(
      """And some text""", 1, 5, @[], @[
         ScopeEntry.new("foo", ControlSequence, Group, 1),
      ]),
   TextSegment.new("""""", 0, 0, @[], @[]),
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
