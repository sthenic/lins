import streams
import terminal
import strformat

include ../../src/lexers/tex_lexer

var
   response: seq[string] = @[]
   nof_passed = 0
   nof_failed = 0


template run_test(title, stimuli: string; reference: seq[TeXToken]) =
   var response: seq[TeXToken] = @[]
   var lex: TeXLexer
   var tok: TeXToken
   init(tok)
   open_lexer(lex, "test", new_string_stream(stimuli))
   while true:
      get_token(lex, tok)
      if tok.token_type == TeXTokenType.EndOfFile:
         break
      add(response, tok)
   close_lexer(lex)

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


# Control sequences
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


# Regular characters
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


# End-of-line characters
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
