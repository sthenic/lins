import streams
import terminal
import strformat

include ../../src/parsers/latex_parser
include ../../src/utils/log

var
   nof_passed = 0
   nof_failed = 0


template run_test(title, stimuli: string; reference: seq[LaTeXTextSegment],
                  debug: bool = false) =
   var response: seq[LaTeXTextSegment] = @[]
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


proc new*(t: typedesc[LaTeXTextSegment], text: string, line, col: int,
          linebreaks: seq[Linebreak], scope: seq[ScopeEntry],
          do_lint: bool = true, expand: bool = false): LaTeXTextSegment =

   result = LaTeXTextSegment(
      base: TextSegment(text: text, line: line, col: col, linebreaks: linebreaks),
      scope: scope, expand: expand, do_lint: do_lint)


proc new*(t: typedesc[ScopeEntry], name: string, kind: ScopeKind,
          encl: Enclosure, count: int, delimiter_count: int = 0,
          context: Context = ("", "")): ScopeEntry =
   result = ScopeEntry(name: name, kind: kind, encl: encl, count: count,
                       delimiter_count: delimiter_count, context: context)


run_test("Simple sentence",
"""A simple sentence.""", @[
   LaTeXTextSegment.new("A simple sentence.", 1, 0, @[], @[])
])


run_test("Multiline sentence",
"""A sentence spanning
several lines
of text.""", @[
   LaTeXTextSegment.new(
      "A sentence spanning several lines of text.", 1, 0,
      @[(20, 2), (34, 3)], @[])
])


run_test("Multiline sentence, irregular spacing",
"""   A sentence  spanning
  several   lines
 of
text.""", @[
   LaTeXTextSegment.new(
      "A sentence spanning several lines of text.", 1, 3,
      @[(20, 2), (34, 3), (37, 4)], @[])
])


run_test("Escaped characters",
"""\%\&\_\#\$\~""", @[
   LaTeXTextSegment.new("%&_#$~", 1, 0, @[], @[])
])


# (La)TeX constructions

run_test("Group w/o control sequence",
"""That's a {\bfseries bold} statement.""", @[
   LaTeXTextSegment.new(
      """That's a bold statement.""", 1, 0, @[], @[])
])


run_test("Option delimiters w/o control sequence",
"""That's a [\bfseries bold] statement.""", @[
   LaTeXTextSegment.new(
      """That's a [bold] statement.""", 1, 0, @[], @[])
])


run_test("Control sequence in text, removed",
"""A sentence \foo with a control sequence.""", @[
   LaTeXTextSegment.new(
      """A sentence with a control sequence.""", 1, 0, @[], @[])
])

run_test("Control sequence in text, expanded",
"""A sentence with \emph{emphasized} text.""", @[
   LaTeXTextSegment.new(
      """A sentence with emphasized text.""", 1, 0, @[], @[])
])


run_test("Expanded control sequence at the beginning of the text segment",
"""\emph{Emphasized} text.""", @[
   LaTeXTextSegment.new(
      """Emphasized text.""", 1, 6, @[], @[])
])


run_test("Expanded control sequence immediately on new line in outer segment",
"""\foo{
   \emph{Emphasized text}}""", @[
   LaTeXTextSegment.new(
      """ Emphasized text""", 1, 5, @[(1, 2)], @[
         ScopeEntry.new("foo", ControlSequence, Group, 1, 1)
      ])
])


run_test("Multiple expanded control sequences, (+linebreak redundancy check)",
"""\foo{
   \emph{This is some emphasized text}
   Yet more text here
   \textsc{Matlab}
   Will it ever end?
   \textbf{A linebreak
   within an expanded segment}
   Finally, it ends!
}""", @[
   LaTeXTextSegment.new(
      " This is some emphasized text Yet more text here Matlab Will it ever " &
      "end? A linebreak within an expanded segment Finally, it ends! ",
      1, 5, @[(1, 2), (30, 3), (49, 4), (56, 5), (74, 6), (86, 7), (113, 8)], @[
         ScopeEntry.new("foo", ControlSequence, Group, 1, 1)
      ])
])


run_test("Control sequence followed by a group",
"""A sentence with \foo{grouped text} another control sequence.""", @[
   LaTeXTextSegment.new(
      """grouped text""", 1, 21, @[], @[
         ScopeEntry.new("foo", ControlSequence, Group, 1, 1, (" sentence with ", ""))
      ]),
   LaTeXTextSegment.new(
      """A sentence with  another control sequence.""", 1, 0, @[], @[]),
])


run_test("Control sequence followed by options",
"""Another sentence with \bar[option text in here]a few options.""", @[
   LaTeXTextSegment.new(
      """option text in here""", 1, 27, @[], @[
         ScopeEntry.new("bar", ControlSequence, Option, 1, 0, (" sentence with ", ""))
      ]),
   LaTeXTextSegment.new(
      """Another sentence with a few options.""", 1, 0, @[], @[]),
])


run_test("Control sequence followed by options and groups",
"""Text before \mycontrolseq[options here]{first group}{second group}.""", @[
   LaTeXTextSegment.new(
      """options here""", 1, 26, @[], @[
         ScopeEntry.new("mycontrolseq", ControlSequence, Option, 1, 0,
         ("Text before ", ""))
      ]),
   LaTeXTextSegment.new(
      """first group""", 1, 40, @[], @[
         ScopeEntry.new("mycontrolseq", ControlSequence, Group, 2, 1,
         ("q[options here]", ""))
      ]),
   LaTeXTextSegment.new(
      """second group""", 1, 53, @[], @[
         ScopeEntry.new("mycontrolseq", ControlSequence, Group, 3, 1,
         ("e]{first group}", ""))
      ]),
   LaTeXTextSegment.new(
      """Text before .""", 1, 0, @[], @[]),
])


run_test("Nested control sequences",
"""\foo{And some \bar{with some} extra} \baz{added for effect}.""", @[
   LaTeXTextSegment.new(
      """with some""", 1, 19, @[], @[
         ScopeEntry.new("foo", ControlSequence, Group, 1, 1, ("", "")),
         ScopeEntry.new("bar", ControlSequence, Group, 1, 2, ("\\foo{And some ", ""))
      ]),
   LaTeXTextSegment.new(
      """And some  extra""", 1, 5, @[], @[
         ScopeEntry.new("foo", ControlSequence, Group, 1, 1, ("", ""))
      ]),
   LaTeXTextSegment.new(
      """added for effect""", 1, 42, @[], @[
         ScopeEntry.new("baz", ControlSequence, Group, 1, 1, ("h some} extra} ", ""))
      ]),
   LaTeXTextSegment.new(
      """ .""", 1, 36, @[], @[]),
])


run_test("Uncaptured group nested in control sequence capture group",
"""\foo{And {some} text}""", @[
   LaTeXTextSegment.new(
      """And some text""", 1, 5, @[], @[
         ScopeEntry.new("foo", ControlSequence, Group, 1, 1),
      ]),
   LaTeXTextSegment.new("""""", 0, 0, @[], @[]),
])


run_test("Control sequence nested in uncaptured group",
"""{some \foo{text} here}""", @[
   LaTeXTextSegment.new(
      """text""", 1, 11, @[], @[
         ScopeEntry.new("foo", ControlSequence, Group, 1, 2, ("{some ", "")),
      ]),
   LaTeXTextSegment.new("""some  here""", 1, 1, @[], @[]),
])


run_test("Multiple levels of nesting, captured & uncaptured groups",
"""\foo{\foo{there {is \foo{some {text \foo{in {here}}}}}""", @[
   LaTeXTextSegment.new(
      """in here""", 1, 41, @[], @[
         ScopeEntry.new("foo", ControlSequence, Group, 1, 1, ("", "")),
         ScopeEntry.new("foo", ControlSequence, Group, 1, 2, ("\\foo{", "")),
         ScopeEntry.new("foo", ControlSequence, Group, 1, 4, ("\\foo{there {is ", "")),
         ScopeEntry.new("foo", ControlSequence, Group, 1, 6, ("foo{some {text ", "")),
      ]),
   LaTeXTextSegment.new(
      """some text """, 1, 25, @[], @[
         ScopeEntry.new("foo", ControlSequence, Group, 1, 1, ("", "")),
         ScopeEntry.new("foo", ControlSequence, Group, 1, 2, ("\\foo{", "")),
         ScopeEntry.new("foo", ControlSequence, Group, 1, 4, ("\\foo{there {is ", "")),
      ]),
   LaTeXTextSegment.new(
      """there is """, 1, 10, @[], @[
         ScopeEntry.new("foo", ControlSequence, Group, 1, 1, ("", "")),
         ScopeEntry.new("foo", ControlSequence, Group, 1, 2, ("\\foo{", "")),
      ]),
   LaTeXTextSegment.new("""some  here""", 1, 1, @[], @[]),
])


run_test("Inline math",
"""A simple sentence with inline $xa_n(k)$ math.""", @[
   LaTeXTextSegment.new("xa_n(k)", 1, 31, @[], @[
      ScopeEntry.new("", ScopeKind.Math, Enclosure.Math, 0, 0, ("ce with inline ", ""))
   ]),
   LaTeXTextSegment.new("A simple sentence with inline  math.", 1, 0, @[], @[])
])


run_test("Inline math with delimiters \\(, \\)",
"""A simple sentence with inline \(xa_n(k)\) math.""", @[
   LaTeXTextSegment.new("xa_n(k)", 1, 32, @[], @[
      ScopeEntry.new("", ScopeKind.Math, Enclosure.Math, 0, 0, ("ce with inline ", ""))
   ]),
   LaTeXTextSegment.new("A simple sentence with inline  math.", 1, 0, @[], @[])
])


run_test("Display math with delimiter $$",
"""A simple sentence with display $$xa_n(k)$$ math.""", @[
   LaTeXTextSegment.new("xa_n(k)", 1, 33, @[], @[
      ScopeEntry.new("", ScopeKind.Math, Enclosure.DisplayMath, 0, 0, ("e with display ", ""))
   ]),
   LaTeXTextSegment.new("A simple sentence with display  math.", 1, 0, @[], @[])
])


run_test("Display math with delimiters \\[, \\]",
"""A simple sentence with display \[xa_n(k)\] math.""", @[
   LaTeXTextSegment.new("xa_n(k)", 1, 33, @[], @[
      ScopeEntry.new("", ScopeKind.Math, Enclosure.DisplayMath, 0, 0, ("e with display ", ""))
   ]),
   LaTeXTextSegment.new("A simple sentence with display  math.", 1, 0, @[], @[])
])


run_test("Option enclosure not allowed in math (equation)",
"""
\begin{equation}
   \frac{x_k^2 + y_k^2}{2},\quad x, y \in [0.5, 1)
\end{equation}""", @[
   LaTeXTextSegment.new("x_k^2 + y_k^2", 2, 9, @[], @[
      ScopeEntry.new("equation", ScopeKind.Environment, Enclosure.Environment, 0),
      ScopeEntry.new("frac", ScopeKind.ControlSequence, Enclosure.Group, 1, 1, ("n{equation}\n   ", "")),
   ]),
   LaTeXTextSegment.new("2", 2, 24, @[], @[
      ScopeEntry.new("equation", ScopeKind.Environment, Enclosure.Environment, 0),
      ScopeEntry.new("frac", ScopeKind.ControlSequence, Enclosure.Group, 2, 1, ("{x_k^2 + y_k^2}", "")),
   ]),
   LaTeXTextSegment.new(" ,x, y [0.5, 1) ", 1, 16, @[(1, 2)], @[
      ScopeEntry.new("equation", ScopeKind.Environment, Enclosure.Environment, 0),
   ]),
])


run_test("Option enclosure not allowed in math (display math)",
"""$$\frac{x_k^2 + y_k^2}{2},\quad x, y \in [0.5, 1)$$""", @[
   LaTeXTextSegment.new("x_k^2 + y_k^2", 1, 8, @[], @[
      ScopeEntry.new("", ScopeKind.Math, Enclosure.DisplayMath, 0),
      ScopeEntry.new("frac", ScopeKind.ControlSequence, Enclosure.Group, 1, 1, ("$$", "")),
   ]),
   LaTeXTextSegment.new("2", 1, 23, @[], @[
      ScopeEntry.new("", ScopeKind.Math, Enclosure.DisplayMath, 0),
      ScopeEntry.new("frac", ScopeKind.ControlSequence, Enclosure.Group, 2, 1, ("{x_k^2 + y_k^2}", "")),
   ]),
   LaTeXTextSegment.new(",x, y [0.5, 1)", 1, 25, @[], @[
      ScopeEntry.new("", ScopeKind.Math, Enclosure.DisplayMath, 0),
   ]),
])


run_test("Option enclosure not allowed in math (inline math)",
"""$\frac{x_k^2 + y_k^2}{2},\quad x, y \in [0.5, 1)$""", @[
   LaTeXTextSegment.new("x_k^2 + y_k^2", 1, 7, @[], @[
      ScopeEntry.new("", ScopeKind.Math, Enclosure.Math, 0),
      ScopeEntry.new("frac", ScopeKind.ControlSequence, Enclosure.Group, 1, 1, ("$", "")),
   ]),
   LaTeXTextSegment.new("2", 1, 22, @[], @[
      ScopeEntry.new("", ScopeKind.Math, Enclosure.Math, 0),
      ScopeEntry.new("frac", ScopeKind.ControlSequence, Enclosure.Group, 2, 1, ("{x_k^2 + y_k^2}", "")),
   ]),
   LaTeXTextSegment.new(",x, y [0.5, 1)", 1, 24, @[], @[
      ScopeEntry.new("", ScopeKind.Math, Enclosure.Math, 0),
   ]),
])


# Environments


run_test("Empty environment", # Without any characters, the starting point is unknown.
"""\begin{empty}\end{empty}""", @[
   LaTeXTextSegment.new("", 0, 0, @[], @[
      ScopeEntry.new("empty", ScopeKind.Environment, Enclosure.Environment, 0),
   ]),
])


run_test("Environment on one line",
"""\begin{environment}Some words.\end{environment}""", @[
   LaTeXTextSegment.new("Some words.", 1, 19, @[], @[
      ScopeEntry.new("environment", ScopeKind.Environment, Enclosure.Environment, 0)
   ]),
])


run_test("Environment spanning several lines",
"""
\begin{tabular}%
Some words. Continuing on
many
lines.
\end{tabular}""", @[
   LaTeXTextSegment.new("Some words. Continuing on many lines. ", 2, 0, @[
      (26, 3), (31, 4)
   ], @[
      ScopeEntry.new("tabular", ScopeKind.Environment, Enclosure.Environment, 0)
   ]),
])


run_test("Environment with nested control sequence, removed",
"""
\begin{tabular}%
The quick brown
fox jumps over the \foo
lazy dog.
\end{tabular}""", @[
   LaTeXTextSegment.new("The quick brown fox jumps over the lazy dog. ", 2, 0, @[
      (16, 3), (35, 4)
   ], @[
      ScopeEntry.new("tabular", ScopeKind.Environment, Enclosure.Environment, 0)
   ]),
])


run_test("Environment with nested control sequence, emitted",
"""
\begin{tabular}%
The quick brown
fox jumps \bar{over the}
lazy dog.
\end{tabular}""", @[
   LaTeXTextSegment.new("over the", 3, 15, @[], @[
      ScopeEntry.new("tabular", ScopeKind.Environment, Enclosure.Environment, 0),
      ScopeEntry.new("bar", ControlSequence, Group, 1, 1, ("rown\nfox jumps ", ""))
   ]),
   LaTeXTextSegment.new("The quick brown fox jumps  lazy dog. ", 2, 0, @[
      (16, 3), (27, 4)
   ], @[
      ScopeEntry.new("tabular", ScopeKind.Environment, Enclosure.Environment, 0)
   ]),
])


run_test("Environment with nested control sequence, expanded",
"""
\begin{tabular}%
The quick brown
fox jumps \emph{over the}
lazy dog.
\end{tabular}""", @[
   LaTeXTextSegment.new("The quick brown fox jumps over the lazy dog. ", 2, 0, @[
      (16, 3), (35, 4)
   ], @[
      ScopeEntry.new("tabular", ScopeKind.Environment, Enclosure.Environment, 0)
   ]),
])


run_test("Environment with space token after closing brace",
"""
\begin{tabular}
The quick brown fox jumps over the lazy dog.
\end{tabular}""", @[
   LaTeXTextSegment.new(" The quick brown fox jumps over the lazy dog. ", 1, 15, @[
      (1, 2)
   ], @[
      ScopeEntry.new("tabular", ScopeKind.Environment, Enclosure.Environment, 0)
   ]),
])


run_test("Environment nested in a control sequence",
"""
\vbox{
   \begin{tabular}%
   The quick brown fox jumps over the lazy dog.
   \end{tabular}
}""", @[
   LaTeXTextSegment.new("The quick brown fox jumps over the lazy dog. ", 3, 3,
      @[], @[
      ScopeEntry.new("vbox", ControlSequence, Group, 1, 1),
      ScopeEntry.new("tabular", ScopeKind.Environment, Enclosure.Environment, 0, 0, ("\\vbox{\n   ", ""))
   ]),
   LaTeXTextSegment.new("  ", 1, 6, @[(1, 4)], @[
      ScopeEntry.new("vbox", ControlSequence, Group, 1, 1)
   ]),
])


run_test("Environment followed by a group",
"""
\begin{mytext}{Capture group 1}%
A simple sentence.
\end{mytext}""", @[
   LaTeXTextSegment.new("Capture group 1", 1, 15, @[], @[
      ScopeEntry.new("mytext", ScopeKind.Environment, Enclosure.Environment, 0),
      ScopeEntry.new("mytext", ScopeKind.Environment, Enclosure.Group, 1, 1, ("\\begin{mytext}", ""))
   ]),
   LaTeXTextSegment.new("A simple sentence. ", 2, 0, @[], @[
      ScopeEntry.new("mytext", ScopeKind.Environment, Enclosure.Environment, 0),
   ]),
])


run_test("Environment followed by options",
"""
\begin{mytext}[a few optional parameters]%
A simple sentence.
\end{mytext}""", @[
   LaTeXTextSegment.new("a few optional parameters", 1, 15, @[], @[
      ScopeEntry.new("mytext", ScopeKind.Environment, Enclosure.Environment, 0),
      ScopeEntry.new("mytext", ScopeKind.Environment, Enclosure.Option, 1, 0, ("\\begin{mytext}", ""))
   ]),
   LaTeXTextSegment.new("A simple sentence. ", 2, 0, @[], @[
      ScopeEntry.new("mytext", ScopeKind.Environment, Enclosure.Environment, 0),
   ]),
])


run_test("Environment followed by options and groups",
"""
\begin{mytext}[up to you to include]{required capture group}{also required}%
A simple sentence.
\end{mytext}""", @[
   LaTeXTextSegment.new("up to you to include", 1, 15, @[], @[
      ScopeEntry.new("mytext", ScopeKind.Environment, Enclosure.Environment, 0),
      ScopeEntry.new("mytext", ScopeKind.Environment, Enclosure.Option, 1, 0, ("\\begin{mytext}", ""))
   ]),
   LaTeXTextSegment.new("required capture group", 1, 37, @[], @[
      ScopeEntry.new("mytext", ScopeKind.Environment, Enclosure.Environment, 0),
      ScopeEntry.new("mytext", ScopeKind.Environment, Enclosure.Group, 2, 1, ("you to include]", ""))
   ]),
   LaTeXTextSegment.new("also required", 1, 61, @[], @[
      ScopeEntry.new("mytext", ScopeKind.Environment, Enclosure.Environment, 0),
      ScopeEntry.new("mytext", ScopeKind.Environment, Enclosure.Group, 3, 1, (" capture group}", ""))
   ]),
   LaTeXTextSegment.new("A simple sentence. ", 2, 0, @[], @[
      ScopeEntry.new("mytext", ScopeKind.Environment, Enclosure.Environment, 0),
   ]),
])


run_test("Starred environment",
"""
\begin{mystar*}%
Contents of a starred environment.
\end{mystar*}""", @[
   LaTeXTextSegment.new("Contents of a starred environment. ", 2, 0, @[], @[
      ScopeEntry.new("mystar*", ScopeKind.Environment, Enclosure.Environment, 0),
   ]),
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
   LaTeXTextSegment.new("ll", 2, 16, @[], @[
      ScopeEntry.new("table", ScopeKind.Environment, Enclosure.Environment, 0),
      ScopeEntry.new("tabular", ScopeKind.Environment, Enclosure.Environment, 0, 0, ("\\begin{table}%\n", "")),
      ScopeEntry.new("tabular", ScopeKind.Environment, Enclosure.Group, 1, 1, ("\\begin{tabular}", "")),
   ]),
   LaTeXTextSegment.new("Header column 0 & Header column 1 ",
   3, 8, @[], @[
      ScopeEntry.new("table", ScopeKind.Environment, Enclosure.Environment, 0),
      ScopeEntry.new("tabular", ScopeKind.Environment, Enclosure.Environment, 0, 0, ("\\begin{table}%\n", ""))
   ]),
   LaTeXTextSegment.new("Row 0, column 0 & Row 0, column 1 ",
   4, 0, @[], @[
      ScopeEntry.new("table", ScopeKind.Environment, Enclosure.Environment, 0),
      ScopeEntry.new("tabular", ScopeKind.Environment, Enclosure.Environment, 0, 0, ("\\begin{table}%\n", ""))
   ]),
   LaTeXTextSegment.new("Row 1, column 0 & Row 1, column 1 ",
   5, 0, @[], @[
      ScopeEntry.new("table", ScopeKind.Environment, Enclosure.Environment, 0),
      ScopeEntry.new("tabular", ScopeKind.Environment, Enclosure.Environment, 0, 0, ("\\begin{table}%\n", ""))
   ]),
   LaTeXTextSegment.new("Row 2, column 0 & Row 2, column 1 ",
   6, 0, @[], @[
      ScopeEntry.new("table", ScopeKind.Environment, Enclosure.Environment, 0),
      ScopeEntry.new("tabular", ScopeKind.Environment, Enclosure.Environment, 0, 0, ("\\begin{table}%\n", ""))
   ]),
   LaTeXTextSegment.new(" ", 7, 13, @[], @[
      ScopeEntry.new("table", ScopeKind.Environment, Enclosure.Environment, 0),
   ]),
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
   LaTeXTextSegment.new("header=Column 0 & Column 1 & Column 2, " &
                        "numcols=3, footer=This is some footer text., " &
                        "caption=This is the table caption. ", 2, 2,
   @[(39, 3), (50, 4), (84, 5)], @[
      ScopeEntry.new("tgtab", ScopeKind.Environment, Enclosure.Environment, 0),
      ScopeEntry.new("tgtab", ScopeKind.Environment, Enclosure.Group, 1, 1, ("\\begin{tgtab}", ""))
   ]),
   LaTeXTextSegment.new(" Row 0, column 0 & Row 0, column 1 & Row 0, column 2 ",
   6, 3, @[(1, 7)], @[
      ScopeEntry.new("tgtab", ScopeKind.Environment, Enclosure.Environment, 0),
   ]),
   LaTeXTextSegment.new(" Row 1, column 0 & Row 1, column 1 & Row 1, column 2 ",
   7, 54, @[(1, 8)], @[
      ScopeEntry.new("tgtab", ScopeKind.Environment, Enclosure.Environment, 0),
   ]),
   LaTeXTextSegment.new(" Row 2, column 0 & Row 2, column 1 & Row 2, column 2 ",
   8, 54, @[(1, 9)], @[
      ScopeEntry.new("tgtab", ScopeKind.Environment, Enclosure.Environment, 0),
   ]),
])


run_test("Segment break on \\cr, (halign case)",
"""
\halign{%
Cell 0: #\hskip 10pt& Cell 1: #\cr
Hello & there! \cr
General & Kenobi! \cr
}
""", @[
   LaTeXTextSegment.new("Cell 0: #10pt& Cell 1: #",
   2, 0, @[], @[
      ScopeEntry.new("halign", ScopeKind.ControlSequence, Enclosure.Group, 1, 1),
   ]),
   LaTeXTextSegment.new("Hello & there! ",
   3, 0, @[], @[
      ScopeEntry.new("halign", ScopeKind.ControlSequence, Enclosure.Group, 1, 1),
   ]),
   LaTeXTextSegment.new("General & Kenobi! ",
   4, 0, @[], @[
      ScopeEntry.new("halign", ScopeKind.ControlSequence, Enclosure.Group, 1, 1),
   ]),
])


run_test("Pangrams: Swedish",
"""Flygande bäckasiner söka hwila på mjuka tuvor.""", @[
   LaTeXTextSegment.new("Flygande bäckasiner söka hwila på mjuka tuvor.", 1, 0, @[], @[]),
])


run_test("Pangrams: French",
"""Ça me fait peur de fêter noël là, sur cette île bizarroïde où une mère et sa môme essaient de me tuer avec un gâteau à la cigüe brûlé.""", @[
   LaTeXTextSegment.new("Ça me fait peur de fêter noël là, sur cette île bizarroïde où une mère et sa môme essaient de me tuer avec un gâteau à la cigüe brûlé.", 1, 0, @[], @[]),
])


run_test("Pangrams: German",
"""Falsches Üben von Xylophonmusik quält jeden größeren Zwerg""", @[
   LaTeXTextSegment.new("Falsches Üben von Xylophonmusik quält jeden größeren Zwerg", 1, 0, @[], @[]),
])


run_test("Pangrams: Spanish",
"""Benjamín pidió una bebida de kiwi y fresa; Noé, sin vergüenza, la más exquisita champaña del menú.""", @[
   LaTeXTextSegment.new("Benjamín pidió una bebida de kiwi y fresa; Noé, sin vergüenza, la más exquisita champaña del menú.", 1, 0, @[], @[]),
])


run_test("Pangrams: Greek",
"""Ταχίστη αλώπηξ βαφής ψημένη γη, δρασκελίζει υπέρ νωθρού κυνός Takhístè alôpèx vaphês psèménè gè, draskelízei ypér nòthroý kynós""", @[
   LaTeXTextSegment.new("Ταχίστη αλώπηξ βαφής ψημένη γη, δρασκελίζει υπέρ νωθρού κυνός Takhístè alôpèx vaphês psèménè gè, draskelízei ypér nòthroý kynós", 1, 0, @[], @[]),
])


run_test("Pangrams: Czech",
"""Nechť již hříšné saxofony ďáblů rozezvučí síň úděsnými tóny waltzu, tanga a quickstepu.""", @[
   LaTeXTextSegment.new("Nechť již hříšné saxofony ďáblů rozezvučí síň úděsnými tóny waltzu, tanga a quickstepu.", 1, 0, @[], @[]),
])


run_test("Pangrams: Japanese",
"""いろはにほへと ちりぬるを わかよたれそ つねならむ うゐのおくやま けふこえて あさきゆめみし ゑひもせす（ん）""", @[
   LaTeXTextSegment.new("いろはにほへと ちりぬるを わかよたれそ つねならむ うゐのおくやま けふこえて あさきゆめみし ゑひもせす（ん）", 1, 0, @[], @[]),
],)


run_test("Itemized list",
"""
\begin{itemize}
\item[0:] A
\item[1:] B
\item[2:] C
\end{itemize}
""", @[
   LaTeXTextSegment.new("0:", 2, 6, @[], @[
      ScopeEntry.new("itemize", ScopeKind.Environment, Enclosure.Environment, 0),
      ScopeEntry.new("item", ScopeKind.ControlSequence, Enclosure.Option, 1, 0, ("begin{itemize}\n", "")),
   ]),
   LaTeXTextSegment.new("1:", 3, 6, @[], @[
      ScopeEntry.new("itemize", ScopeKind.Environment, Enclosure.Environment, 0),
      ScopeEntry.new("item", ScopeKind.ControlSequence, Enclosure.Option, 1, 0, ("e}\n\\item[0:] A\n", "")),
   ]),
   LaTeXTextSegment.new("2:", 4, 6, @[], @[
      ScopeEntry.new("itemize", ScopeKind.Environment, Enclosure.Environment, 0),
      ScopeEntry.new("item", ScopeKind.ControlSequence, Enclosure.Option, 1, 0, (" A\n\\item[1:] B\n", "")),
   ]),
   LaTeXTextSegment.new("  A  B  C ", 1, 15, @[(1, 2), (4, 3), (7, 4)], @[
      ScopeEntry.new("itemize", ScopeKind.Environment, Enclosure.Environment, 0),
   ]),
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
