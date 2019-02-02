import streams
import terminal
import strformat

include ../../src/lexers/tex_lexer

var
   response: seq[string] = @[]
   nof_passed = 0
   nof_failed = 0


template run_test(title, stimuli: string; reference: seq[TeXToken],
                  debug: bool = false) =
   var response: seq[TeXToken] = @[]
   var lex: TeXLexer
   var tok: TeXToken
   init(tok)
   open_lexer(lex, "test", new_string_stream(stimuli), false)
   while true:
      get_token(lex, tok)
      if tok.token_type == TeXTokenType.EndOfFile:
         break
      add(response, tok)
   close_lexer(lex)

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


# We define a custom constructor to be able to provide a default value to the
# context without intruding on the full constructor in the lexer module.
proc new*(t: typedesc[TeXToken], token_type: TeXTokenType,
         catcode: CategoryCode, token: string, line, col: int): TeXToken =
   result = TeXToken(token_type: token_type, catcode: catcode, token: token,
                     line: line, col: col, context: ("", ""))


# Control sequences (category 0)
run_test("Control word",
"""\foo""", @[
   TeXToken.new(ControlWord, 0, "foo", 1, 0),
])

run_test("Control space",
"""\ a""", @[
   TeXToken.new(ControlSymbol, 0, " ", 1, 0),
   TeXToken.new(Character, 11, "a", 1, 2),
])

run_test("Control symbol",
"""\%""", @[
   TeXToken.new(ControlSymbol, 0, "%", 1, 0),
])

run_test("Empty control sequence, ending on EOF",
"""\""", @[
   TeXToken.new(ControlWord, 0, "", 1, 0),
])

run_test("Empty control sequence, ending on end-of-line",
"""\
""", @[
   TeXToken.new(ControlWord, 0, "", 1, 0),
   TeXToken.new(ControlWord, 0, "par", 1, 1),
])

run_test("Ignore space after control word",
"""\foo  bar""", @[
   TeXToken.new(ControlWord, 0, "foo", 1, 0),
   TeXToken.new(Character, 11, "b", 1, 6),
   TeXToken.new(Character, 11, "a", 1, 7),
   TeXToken.new(Character, 11, "r", 1, 8),
])

run_test("Ignore space after control space",
"""\   bar""", @[
   TeXToken.new(ControlSymbol, 0, " ", 1, 0),
   TeXToken.new(Character, 11, "b", 1, 4),
   TeXToken.new(Character, 11, "a", 1, 5),
   TeXToken.new(Character, 11, "r", 1, 6),
])

run_test("Don't ignore space after control symbol",
"""\&   bar""", @[
   TeXToken.new(ControlSymbol, 0, "&", 1, 0),
   TeXToken.new(Character, 10, " ", 1, 2),
   TeXToken.new(Character, 11, "b", 1, 5),
   TeXToken.new(Character, 11, "a", 1, 6),
   TeXToken.new(Character, 11, "r", 1, 7),
])


# Category 7 replacement

run_test("Category 7, trio replacement, subtraction",
"""a ^^J b""", @[
   TeXToken.new(Character, 11, "a", 1, 0),
   TeXToken.new(Character, 10, " ", 1, 1),
   TeXToken.new(Character, 11, "b", 2, 1),
])

run_test("Category 7, trio replacement, addition",
"""a ^^0 b""", @[
   TeXToken.new(Character, 11, "a", 1, 0),
   TeXToken.new(Character, 10, " ", 1, 1),
   TeXToken.new(Character, 11, "p", 1, 4),
   TeXToken.new(Character, 10, " ", 1, 5),
   TeXToken.new(Character, 11, "b", 1, 6),
])

run_test("Category 7, quartet replacement",
"""a ^^30^^31 ^^0Ab""", @[
   TeXToken.new(Character, 11, "a", 1, 0),
   TeXToken.new(Character, 10, " ", 1, 1),
   TeXToken.new(Character, 12, "0", 1, 5),
   TeXToken.new(Character, 12, "1", 1, 9),
   TeXToken.new(Character, 10, " ", 1, 10),
   TeXToken.new(Character, 11, "b", 2, 0),
])

run_test("Category 7, no replacement",
"""a ^ ^30 b""", @[
   TeXToken.new(Character, 11, "a", 1, 0),
   TeXToken.new(Character, 10, " ", 1, 1),
   TeXToken.new(Character, 7, "^", 1, 2),
   TeXToken.new(Character, 10, " ", 1, 3),
   TeXToken.new(Character, 7, "^", 1, 4),
   TeXToken.new(Character, 12, "3", 1, 5),
   TeXToken.new(Character, 12, "0", 1, 6),
   TeXToken.new(Character, 10, " ", 1, 7),
   TeXToken.new(Character, 11, "b", 1, 8),
])

run_test("Category 7, trio replacement in control word (first character)",
"""\^^!bc""", @[
   TeXToken.new(ControlWord, 0, "abc", 1, 0),
])

run_test("Category 7, trio replacement in control word, (second character)",
"""\a^^"c""", @[
   TeXToken.new(ControlWord, 0, "abc", 1, 0),
])

run_test("Category 7, trio replacement in control word, (last character)",
"""\ab^^#""", @[
   TeXToken.new(ControlWord, 0, "abc", 1, 0),
])

run_test("Category 7, quartet replacement in control word (first character)",
"""\^^61bc""", @[
   TeXToken.new(ControlWord, 0, "abc", 1, 0),
])

run_test("Category 7, quartet replacement in control word (second character)",
"""\a^^62c""", @[
   TeXToken.new(ControlWord, 0, "abc", 1, 0),
])

run_test("Category 7, quartet replacement in control word (last character)",
"""\ab^^63""", @[
   TeXToken.new(ControlWord, 0, "abc", 1, 0),
])

# 'Regular' characters (categories 1, 2, 3, 4, 6, 8, 11, 12 or 13 or 7 w/o replacement)
run_test("Simple sentence",
"""A lazy dog.""", @[
   TeXToken.new(Character, 11, "A", 1, 0),
   TeXToken.new(Character, 10, " ", 1, 1),
   TeXToken.new(Character, 11, "l", 1, 2),
   TeXToken.new(Character, 11, "a", 1, 3),
   TeXToken.new(Character, 11, "z", 1, 4),
   TeXToken.new(Character, 11, "y", 1, 5),
   TeXToken.new(Character, 10, " ", 1, 6),
   TeXToken.new(Character, 11, "d", 1, 7),
   TeXToken.new(Character, 11, "o", 1, 8),
   TeXToken.new(Character, 11, "g", 1, 9),
   TeXToken.new(Character, 12, ".", 1, 10),
])

run_test("Characters appended from state M",
"""a{}$&#^_Az(~""", @[
   TeXToken.new(Character, 11, "a", 1, 0),
   TeXToken.new(Character, 1, "{", 1, 1),
   TeXToken.new(Character, 2, "}", 1, 2),
   TeXToken.new(Character, 3, "$", 1, 3),
   TeXToken.new(Character, 4, "&", 1, 4),
   TeXToken.new(Character, 6, "#", 1, 5),
   TeXToken.new(Character, 7, "^", 1, 6),
   TeXToken.new(Character, 8, "_", 1, 7),
   TeXToken.new(Character, 11, "A", 1, 8),
   TeXToken.new(Character, 11, "z", 1, 9),
   TeXToken.new(Character, 12, "(", 1, 10),
   TeXToken.new(Character, 13, "~", 1, 11),
])

run_test("Characters appended from state N",
"{\n}\n$\n&\n#\n^\n_\nA\nz\n(\n~", @[
   TeXToken.new(Character, 1, "{", 1, 0),
   TeXToken.new(Character, 10, " ", 1, 1),
   TeXToken.new(Character, 2, "}", 2, 0),
   TeXToken.new(Character, 10, " ", 2, 1),
   TeXToken.new(Character, 3, "$", 3, 0),
   TeXToken.new(Character, 10, " ", 3, 1),
   TeXToken.new(Character, 4, "&", 4, 0),
   TeXToken.new(Character, 10, " ", 4, 1),
   TeXToken.new(Character, 6, "#", 5, 0),
   TeXToken.new(Character, 10, " ", 5, 1),
   TeXToken.new(Character, 7, "^", 6, 0),
   TeXToken.new(Character, 10, " ", 6, 1),
   TeXToken.new(Character, 8, "_", 7, 0),
   TeXToken.new(Character, 10, " ", 7, 1),
   TeXToken.new(Character, 11, "A", 8, 0),
   TeXToken.new(Character, 10, " ", 8, 1),
   TeXToken.new(Character, 11, "z", 9, 0),
   TeXToken.new(Character, 10, " ", 9, 1),
   TeXToken.new(Character, 12, "(", 10, 0),
   TeXToken.new(Character, 10, " ", 10, 1),
   TeXToken.new(Character, 13, "~", 11, 0),
])

run_test("Characters appended from state S",
"""
a {
a }
a $
a &
a #
a ^
a _
a A
a z
a (
a ~""", @[
   TeXToken.new(Character, 11, "a", 1, 0),
   TeXToken.new(Character, 10, " ", 1, 1),
   TeXToken.new(Character, 1, "{", 1, 2),
   TeXToken.new(Character, 10, " ", 1, 3),

   TeXToken.new(Character, 11, "a", 2, 0),
   TeXToken.new(Character, 10, " ", 2, 1),
   TeXToken.new(Character, 2, "}", 2, 2),
   TeXToken.new(Character, 10, " ", 2, 3),

   TeXToken.new(Character, 11, "a", 3, 0),
   TeXToken.new(Character, 10, " ", 3, 1),
   TeXToken.new(Character, 3, "$", 3, 2),
   TeXToken.new(Character, 10, " ", 3, 3),

   TeXToken.new(Character, 11, "a", 4, 0),
   TeXToken.new(Character, 10, " ", 4, 1),
   TeXToken.new(Character, 4, "&", 4, 2),
   TeXToken.new(Character, 10, " ", 4, 3),

   TeXToken.new(Character, 11, "a", 5, 0),
   TeXToken.new(Character, 10, " ", 5, 1),
   TeXToken.new(Character, 6, "#", 5, 2),
   TeXToken.new(Character, 10, " ", 5, 3),

   TeXToken.new(Character, 11, "a", 6, 0),
   TeXToken.new(Character, 10, " ", 6, 1),
   TeXToken.new(Character, 7, "^", 6, 2),
   TeXToken.new(Character, 10, " ", 6, 3),

   TeXToken.new(Character, 11, "a", 7, 0),
   TeXToken.new(Character, 10, " ", 7, 1),
   TeXToken.new(Character, 8, "_", 7, 2),
   TeXToken.new(Character, 10, " ", 7, 3),

   TeXToken.new(Character, 11, "a", 8, 0),
   TeXToken.new(Character, 10, " ", 8, 1),
   TeXToken.new(Character, 11, "A", 8, 2),
   TeXToken.new(Character, 10, " ", 8, 3),

   TeXToken.new(Character, 11, "a", 9, 0),
   TeXToken.new(Character, 10, " ", 9, 1),
   TeXToken.new(Character, 11, "z", 9, 2),
   TeXToken.new(Character, 10, " ", 9, 3),

   TeXToken.new(Character, 11, "a", 10, 0),
   TeXToken.new(Character, 10, " ", 10, 1),
   TeXToken.new(Character, 12, "(", 10, 2),
   TeXToken.new(Character, 10, " ", 10, 3),

   TeXToken.new(Character, 11, "a", 11, 0),
   TeXToken.new(Character, 10, " ", 11, 1),
   TeXToken.new(Character, 13, "~", 11, 2),
])


# End-of-line characters (category 5)
run_test("End-of-line in state N",
"""
""", @[
   TeXToken.new(ControlWord, 0, "par", 1, 1),
])

run_test("End-of-line in state S",
"""\foo
""", @[
   TeXToken.new(ControlWord, 0, "foo", 1, 0),
])

run_test("End-of-line in state M",
"""Word
""", @[
   TeXToken.new(Character, 11, "W", 1, 0),
   TeXToken.new(Character, 11, "o", 1, 1),
   TeXToken.new(Character, 11, "r", 1, 2),
   TeXToken.new(Character, 11, "d", 1, 3),
   TeXToken.new(Character, 10, " ", 1, 4),
])

# Ignored characters

# Space characters (category 10)

run_test("Space character in state M",
"""A """, @[
   TeXToken.new(Character, 11, "A", 1, 0),
   TeXToken.new(Character, 10, " ", 1, 1),
])

run_test("Space character in state S",
"""A  """, @[
   TeXToken.new(Character, 11, "A", 1, 0),
   TeXToken.new(Character, 10, " ", 1, 1),
])

run_test("Space character in state N",
"""   A""", @[
   TeXToken.new(Character, 11, "A", 1, 3),
])

# Comment characters (category 14)

run_test("Comment string",
"""
1st line % a comment string, will be discarded
2nd line""", @[
   TeXToken.new(Character, 12, "1", 1, 0),
   TeXToken.new(Character, 11, "s", 1, 1),
   TeXToken.new(Character, 11, "t", 1, 2),
   TeXToken.new(Character, 10, " ", 1, 3),
   TeXToken.new(Character, 11, "l", 1, 4),
   TeXToken.new(Character, 11, "i", 1, 5),
   TeXToken.new(Character, 11, "n", 1, 6),
   TeXToken.new(Character, 11, "e", 1, 7),
   TeXToken.new(Character, 10, " ", 1, 8),

   TeXToken.new(Character, 12, "2", 2, 0),
   TeXToken.new(Character, 11, "n", 2, 1),
   TeXToken.new(Character, 11, "d", 2, 2),
   TeXToken.new(Character, 10, " ", 2, 3),
   TeXToken.new(Character, 11, "l", 2, 4),
   TeXToken.new(Character, 11, "i", 2, 5),
   TeXToken.new(Character, 11, "n", 2, 6),
   TeXToken.new(Character, 11, "e", 2, 7),
])

run_test("Comment character blocking end-of-line space insertion",
"""
1st line%
2nd line""", @[
   TeXToken.new(Character, 12, "1", 1, 0),
   TeXToken.new(Character, 11, "s", 1, 1),
   TeXToken.new(Character, 11, "t", 1, 2),
   TeXToken.new(Character, 10, " ", 1, 3),
   TeXToken.new(Character, 11, "l", 1, 4),
   TeXToken.new(Character, 11, "i", 1, 5),
   TeXToken.new(Character, 11, "n", 1, 6),
   TeXToken.new(Character, 11, "e", 1, 7),

   TeXToken.new(Character, 12, "2", 2, 0),
   TeXToken.new(Character, 11, "n", 2, 1),
   TeXToken.new(Character, 11, "d", 2, 2),
   TeXToken.new(Character, 10, " ", 2, 3),
   TeXToken.new(Character, 11, "l", 2, 4),
   TeXToken.new(Character, 11, "i", 2, 5),
   TeXToken.new(Character, 11, "n", 2, 6),
   TeXToken.new(Character, 11, "e", 2, 7),
])

run_test("Comment character skipping \\par token insertion",
"""
a%
%
b""", @[
   TeXToken.new(Character, 11, "a", 1, 0),
   TeXToken.new(Character, 11, "b", 3, 0),
])

run_test("Comment string with keyword",
"""
a% TODO: Look at this later
b""", @[
   TeXToken.new(Character, 11, "a", 1, 0),
   TeXToken.new(Comment, 0, "TODO", 1, 3),
   TeXToken.new(Character, 11, "b", 2, 0),
])

run_test("Comment string with hyphenated keyword",
"""
a
% lins-enable
b""", @[
   TeXToken.new(Character, 11, "a", 1, 0),
   TeXToken.new(Character, 10, " ", 1, 1),
   TeXToken.new(Comment, 0, "lins-enable", 2, 2),
   TeXToken.new(Character, 11, "b", 3, 0),
])

run_test("Comment string with multiple keywords",
"""
a
%lins-disable TODO: Important stuff FIXME: Right now! XXX: Marks the spot
b""", @[
   TeXToken.new(Character, 11, "a", 1, 0),
   TeXToken.new(Character, 10, " ", 1, 1),
   TeXToken.new(Comment, 0, "lins-disable", 2, 1),
   TeXToken.new(Comment, 0, "TODO", 2, 14),
   TeXToken.new(Comment, 0, "FIXME", 2, 36),
   TeXToken.new(Comment, 0, "XXX", 2, 54),
   TeXToken.new(Character, 11, "b", 3, 0),
])

# Invalid characters (category 15)

run_test("Invalid character, removed", # Should we raise an exception?
"Word \x08word", @[
   TeXToken.new(Character, 11, "W", 1, 0),
   TeXToken.new(Character, 11, "o", 1, 1),
   TeXToken.new(Character, 11, "r", 1, 2),
   TeXToken.new(Character, 11, "d", 1, 3),
   TeXToken.new(Character, 10, " ", 1, 4),
   TeXToken.new(Character, 11, "w", 1, 6),
   TeXToken.new(Character, 11, "o", 1, 7),
   TeXToken.new(Character, 11, "r", 1, 8),
   TeXToken.new(Character, 11, "d", 1, 9),
])

# Non-english characters, Unicode etc.
run_test("Non-ASCII characters: Swedish",
"""åäöÅÄÖ""", @[
   TeXToken.new(Character, 12, "\xC3", 1, 0),
   TeXToken.new(Character, 12, "\xA5", 1, 1),

   TeXToken.new(Character, 12, "\xC3", 1, 2),
   TeXToken.new(Character, 12, "\xA4", 1, 3),

   TeXToken.new(Character, 12, "\xC3", 1, 4),
   TeXToken.new(Character, 12, "\xB6", 1, 5),

   TeXToken.new(Character, 12, "\xC3", 1, 6),
   TeXToken.new(Character, 12, "\x85", 1, 7),

   TeXToken.new(Character, 12, "\xC3", 1, 8),
   TeXToken.new(Character, 12, "\x84", 1, 9),

   TeXToken.new(Character, 12, "\xC3", 1, 10),
   TeXToken.new(Character, 12, "\x96", 1, 11),
])

run_test("Non-ASCII characters: French",
"""Çêëèéàâûùüôîï""", @[
   TeXToken.new(Character, 12, "\xC3", 1, 0),
   TeXToken.new(Character, 12, "\x87", 1, 1),

   TeXToken.new(Character, 12, "\xC3", 1, 2),
   TeXToken.new(Character, 12, "\xAA", 1, 3),

   TeXToken.new(Character, 12, "\xC3", 1, 4),
   TeXToken.new(Character, 12, "\xAB", 1, 5),

   TeXToken.new(Character, 12, "\xC3", 1, 6),
   TeXToken.new(Character, 12, "\xA8", 1, 7),

   TeXToken.new(Character, 12, "\xC3", 1, 8),
   TeXToken.new(Character, 12, "\xA9", 1, 9),

   TeXToken.new(Character, 12, "\xC3", 1, 10),
   TeXToken.new(Character, 12, "\xA0", 1, 11),

   TeXToken.new(Character, 12, "\xC3", 1, 12),
   TeXToken.new(Character, 12, "\xA2", 1, 13),

   TeXToken.new(Character, 12, "\xC3", 1, 14),
   TeXToken.new(Character, 12, "\xBB", 1, 15),

   TeXToken.new(Character, 12, "\xC3", 1, 16),
   TeXToken.new(Character, 12, "\xB9", 1, 17),

   TeXToken.new(Character, 12, "\xC3", 1, 18),
   TeXToken.new(Character, 12, "\xBC", 1, 19),

   TeXToken.new(Character, 12, "\xC3", 1, 20),
   TeXToken.new(Character, 12, "\xB4", 1, 21),

   TeXToken.new(Character, 12, "\xC3", 1, 22),
   TeXToken.new(Character, 12, "\xAE", 1, 23),

   TeXToken.new(Character, 12, "\xC3", 1, 24),
   TeXToken.new(Character, 12, "\xAF", 1, 25),
])

run_test("Non-ASCII characters: German",
"""ß""", @[
   TeXToken.new(Character, 12, "\xC3", 1, 0),
   TeXToken.new(Character, 12, "\x9F", 1, 1),
])

run_test("Non-ASCII characters: Emojis",
"""😆😇""", @[
   TeXToken.new(Character, 12, "\xF0", 1, 0),
   TeXToken.new(Character, 12, "\x9F", 1, 1),
   TeXToken.new(Character, 12, "\x98", 1, 2),
   TeXToken.new(Character, 12, "\x86", 1, 3),

   TeXToken.new(Character, 12, "\xF0", 1, 4),
   TeXToken.new(Character, 12, "\x9F", 1, 5),
   TeXToken.new(Character, 12, "\x98", 1, 6),
   TeXToken.new(Character, 12, "\x87", 1, 7),
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
