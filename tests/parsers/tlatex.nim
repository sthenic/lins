import streams
import terminal
import strformat

include ../../src/parsers/latex_parser
include ../../src/utils/log

var
   nof_passed = 0
   nof_failed = 0


template run_test(title, stimuli: string; reference: seq[TextSegment],
                  debug: bool = false) =
   var response: seq[TextSegment] = @[]
   response = parse_string(stimuli)
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


run_test("Expanded control sequence at the beginning of the text segment",
"""\emph{Emphasized} text.""", @[
   TextSegment.new(
      """Emphasized text.""", 1, 6, @[], @[])
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


run_test("Inline math",
"""A simple sentence with inline $xa_n(k)$ math.""", @[
   TextSegment.new("xa_n(k)", 1, 31, @[], @[
      ScopeEntry.new("", ScopeKind.Math, Enclosure.Math, 0)
   ]),
   TextSegment.new("A simple sentence with inline  math.", 1, 0, @[], @[])
])


run_test("Inline math with delimiters \\(, \\)",
"""A simple sentence with inline \(xa_n(k)\) math.""", @[
   TextSegment.new("xa_n(k)", 1, 32, @[], @[
      ScopeEntry.new("", ScopeKind.Math, Enclosure.Math, 0)
   ]),
   TextSegment.new("A simple sentence with inline  math.", 1, 0, @[], @[])
])


run_test("Display math with delimiter $$",
"""A simple sentence with display $$xa_n(k)$$ math.""", @[
   TextSegment.new("xa_n(k)", 1, 33, @[], @[
      ScopeEntry.new("", ScopeKind.Math, Enclosure.DisplayMath, 0)
   ]),
   TextSegment.new("A simple sentence with display  math.", 1, 0, @[], @[])
])


run_test("Display math with delimiters \\[, \\]",
"""A simple sentence with display \[xa_n(k)\] math.""", @[
   TextSegment.new("xa_n(k)", 1, 33, @[], @[
      ScopeEntry.new("", ScopeKind.Math, Enclosure.DisplayMath, 0)
   ]),
   TextSegment.new("A simple sentence with display  math.", 1, 0, @[], @[])
])


# Environments


run_test("Empty environment", # Without any characters, the starting point is unknown.
"""\begin{empty}\end{empty}""", @[
   TextSegment.new("", 0, 0, @[], @[
      ScopeEntry.new("empty", ScopeKind.Environment, Enclosure.Environment, 0),
   ]),
   TextSegment.new("", 0, 0, @[], @[]) # Empty segment
])


run_test("Environment on one line",
"""\begin{environment}Some words.\end{environment}""", @[
   TextSegment.new("Some words.", 1, 19, @[], @[
      ScopeEntry.new("environment", ScopeKind.Environment, Enclosure.Environment, 0)
   ]),
   TextSegment.new("", 0, 0, @[], @[]) # Empty segment
])


run_test("Environment spanning several lines",
"""
\begin{tabular}%
Some words. Continuing on
many
lines.
\end{tabular}""", @[
   TextSegment.new("Some words. Continuing on many lines. ", 2, 0, @[
      (26, 3), (31, 4)
   ], @[
      ScopeEntry.new("tabular", ScopeKind.Environment, Enclosure.Environment, 0)
   ]),
   TextSegment.new("", 0, 0, @[], @[]) # Empty segment
])


run_test("Environment with nested control sequence, removed",
"""
\begin{tabular}%
The quick brown
fox jumps over the \foo
lazy dog.
\end{tabular}""", @[
   TextSegment.new("The quick brown fox jumps over the lazy dog. ", 2, 0, @[
      (16, 3), (35, 4)
   ], @[
      ScopeEntry.new("tabular", ScopeKind.Environment, Enclosure.Environment, 0)
   ]),
   TextSegment.new("", 0, 0, @[], @[]) # Empty segment
])


run_test("Environment with nested control sequence, emitted",
"""
\begin{tabular}%
The quick brown
fox jumps \bar{over the}
lazy dog.
\end{tabular}""", @[
   TextSegment.new("over the", 3, 15, @[], @[
      ScopeEntry.new("tabular", ScopeKind.Environment, Enclosure.Environment, 0),
      ScopeEntry.new("bar", ControlSequence, Group, 1)
   ]),
   TextSegment.new("The quick brown fox jumps  lazy dog. ", 2, 0, @[
      (16, 3), (27, 4)
   ], @[
      ScopeEntry.new("tabular", ScopeKind.Environment, Enclosure.Environment, 0)
   ]),
   TextSegment.new("", 0, 0, @[], @[]) # Empty segment
])


run_test("Environment with nested control sequence, expanded",
"""
\begin{tabular}%
The quick brown
fox jumps \texttt{over the}
lazy dog.
\end{tabular}""", @[
   TextSegment.new("The quick brown fox jumps over the lazy dog. ", 2, 0, @[
      (16, 3), (35, 4)
   ], @[
      ScopeEntry.new("tabular", ScopeKind.Environment, Enclosure.Environment, 0)
   ]),
   TextSegment.new("", 0, 0, @[], @[]) # Empty segment
])


run_test("Environment with space token after closing brace",
"""
\begin{tabular}
The quick brown fox jumps over the lazy dog.
\end{tabular}""", @[
   TextSegment.new(" The quick brown fox jumps over the lazy dog. ", 1, 15, @[
      (1, 2)
   ], @[
      ScopeEntry.new("tabular", ScopeKind.Environment, Enclosure.Environment, 0)
   ]),
   TextSegment.new("", 0, 0, @[], @[]) # Empty segment
])


run_test("Environment nested in a control sequence",
"""
\vbox{
   \begin{tabular}%
   The quick brown fox jumps over the lazy dog.
   \end{tabular}
}""", @[
   TextSegment.new("The quick brown fox jumps over the lazy dog. ", 3, 3,
      @[], @[
      ScopeEntry.new("vbox", ControlSequence, Group, 1),
      ScopeEntry.new("tabular", ScopeKind.Environment, Enclosure.Environment, 0)
   ]),
   TextSegment.new("  ", 1, 6, @[(1, 4)], @[
      ScopeEntry.new("vbox", ControlSequence, Group, 1)
   ]),
   TextSegment.new("", 0, 0, @[], @[]) # Empty segment
])


run_test("Environment followed by a group",
"""
\begin{mytext}{Capture group 1}%
A simple sentence.
\end{mytext}""", @[
   TextSegment.new("Capture group 1", 1, 15, @[], @[
      ScopeEntry.new("mytext", ScopeKind.Environment, Enclosure.Environment, 0),
      ScopeEntry.new("mytext", ScopeKind.Environment, Enclosure.Group, 1)
   ]),
   TextSegment.new("A simple sentence. ", 2, 0, @[], @[
      ScopeEntry.new("mytext", ScopeKind.Environment, Enclosure.Environment, 0),
   ]),
   TextSegment.new("", 0, 0, @[], @[]) # Empty segment
])


run_test("Environment followed by options",
"""
\begin{mytext}[a few optional parameters]%
A simple sentence.
\end{mytext}""", @[
   TextSegment.new("a few optional parameters", 1, 15, @[], @[
      ScopeEntry.new("mytext", ScopeKind.Environment, Enclosure.Environment, 0),
      ScopeEntry.new("mytext", ScopeKind.Environment, Enclosure.Option, 1)
   ]),
   TextSegment.new("A simple sentence. ", 2, 0, @[], @[
      ScopeEntry.new("mytext", ScopeKind.Environment, Enclosure.Environment, 0),
   ]),
   TextSegment.new("", 0, 0, @[], @[]) # Empty segment
])


run_test("Environment followed by options and groups",
"""
\begin{mytext}[up to you to include]{required capture group}{also required}%
A simple sentence.
\end{mytext}""", @[
   TextSegment.new("up to you to include", 1, 15, @[], @[
      ScopeEntry.new("mytext", ScopeKind.Environment, Enclosure.Environment, 0),
      ScopeEntry.new("mytext", ScopeKind.Environment, Enclosure.Option, 1)
   ]),
   TextSegment.new("required capture group", 1, 37, @[], @[
      ScopeEntry.new("mytext", ScopeKind.Environment, Enclosure.Environment, 0),
      ScopeEntry.new("mytext", ScopeKind.Environment, Enclosure.Group, 2)
   ]),
   TextSegment.new("also required", 1, 61, @[], @[
      ScopeEntry.new("mytext", ScopeKind.Environment, Enclosure.Environment, 0),
      ScopeEntry.new("mytext", ScopeKind.Environment, Enclosure.Group, 3)
   ]),
   TextSegment.new("A simple sentence. ", 2, 0, @[], @[
      ScopeEntry.new("mytext", ScopeKind.Environment, Enclosure.Environment, 0),
   ]),
   TextSegment.new("", 0, 0, @[], @[]) # Empty segment
])


run_test("Starred environment",
"""
\begin{mystar*}%
Contents of a starred environment.
\end{mystar*}""", @[
   TextSegment.new("Contents of a starred environment. ", 2, 0, @[], @[
      ScopeEntry.new("mystar*", ScopeKind.Environment, Enclosure.Environment, 0),
   ]),
   TextSegment.new("", 0, 0, @[], @[]) # Empty segment
])


run_test("Table environment: table nested with tabular",
"""
\begin{table}%
\begin{tabular}{ll}%
\textbf{Header column 0} & \textbf{Header column 1} \\\hline
Row 0, column 0 & Row 0, column 1 \\\hline
Row 1, column 0 & Row 1, column 1 \\\hline
Row 2, column 0 & Row 2, column 1
\end{tabular}
\end{table}""", @[
   TextSegment.new("ll", 2, 16, @[], @[
      ScopeEntry.new("table", ScopeKind.Environment, Enclosure.Environment, 0),
      ScopeEntry.new("tabular", ScopeKind.Environment, Enclosure.Environment, 0),
      ScopeEntry.new("tabular", ScopeKind.Environment, Enclosure.Group, 1),
   ]),
   TextSegment.new("Header column 0 & Header column 1 Row 0, column 0 & Row 0, column 1 Row 1, column 0 & Row 1, column 1 Row 2, column 0 & Row 2, column 1 ",
   3, 8, @[(34, 4), (68, 5), (102, 6)], @[
      ScopeEntry.new("table", ScopeKind.Environment, Enclosure.Environment, 0),
      ScopeEntry.new("tabular", ScopeKind.Environment, Enclosure.Environment, 0)
   ]),
   TextSegment.new(" ", 7, 13, @[], @[
      ScopeEntry.new("table", ScopeKind.Environment, Enclosure.Environment, 0),
   ]),
   TextSegment.new("", 0, 0, @[], @[]) # Empty segment
])


run_test("Complex environment",
"""
\begin{tgtab}{%
  header={\textbf{Column 0} & \textbf{Column 1} & \textbf{Column 2}},
  numcols=3,
  footer={This is some footer text.},
  caption={This is the table caption.}
}{}
Row 0, column 0 & Row 0, column 1 & Row 0, column 2 \\
Row 1, column 0 & Row 1, column 1 & Row 1, column 2 \\
Row 2, column 0 & Row 2, column 1 & Row 2, column 2
\end{tgtab}
""", @[
   TextSegment.new("header=Column 0 & Column 1 & Column 2, " &
                   "numcols=3, footer=This is some footer text., " &
                   "caption=This is the table caption. ", 2, 2,
   @[
      (39, 3), (50, 4), (84, 5)
   ], @[
      ScopeEntry.new("tgtab", ScopeKind.Environment, Enclosure.Environment, 0),
      ScopeEntry.new("tgtab", ScopeKind.Environment, Enclosure.Group, 1)
   ]),
   TextSegment.new("", 0, 0, @[], @[
      ScopeEntry.new("tgtab", ScopeKind.Environment, Enclosure.Environment, 0),
      ScopeEntry.new("tgtab", ScopeKind.Environment, Enclosure.Group, 2)
   ]),
   TextSegment.new(" Row 0, column 0 & Row 0, column 1 & Row 0, column 2  " &
                   "Row 1, column 0 & Row 1, column 1 & Row 1, column 2  " &
                   "Row 2, column 0 & Row 2, column 1 & Row 2, column 2 ", 6, 3,
   @[
      (1, 7), (54, 8), (107, 9)
   ], @[
      ScopeEntry.new("tgtab", ScopeKind.Environment, Enclosure.Environment, 0),
   ]),
   TextSegment.new(" ", 10, 11, @[], @[]),
   TextSegment.new("", 0, 0, @[], @[]) # Empty segment
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
