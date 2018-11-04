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


run_test("Simple sentence",
"""A lazy dog.""", @[
   TeXToken.new(TeXTokenType.Character, 11, "A", 1, 0),
   TeXToken.new(TeXTokenType.Character, 10, " ", 1, 1),
   TeXToken.new(TeXTokenType.Character, 11, "l", 1, 2),
   TeXToken.new(TeXTokenType.Character, 11, "a", 1, 3),
   TeXToken.new(TeXTokenType.Character, 11, "z", 1, 4),
   TeXToken.new(TeXTokenType.Character, 11, "y", 1, 5),
   TeXToken.new(TeXTokenType.Character, 10, " ", 1, 6),
   TeXToken.new(TeXTokenType.Character, 11, "d", 1, 7),
   TeXToken.new(TeXTokenType.Character, 11, "o", 1, 8),
   TeXToken.new(TeXTokenType.Character, 11, "g", 1, 9),
   TeXToken.new(TeXTokenType.Character, 12, ".", 1, 10),
])

run_test("Control word",
"""\foo""", @[
   TeXToken.new(TeXTokenType.ControlWord, 0, "foo", 1, 0),
])

run_test("Ignore space after control word",
"""\foo  bar""", @[
   TeXToken.new(TeXTokenType.ControlWord, 0, "foo", 1, 0),
   TeXToken.new(TeXTokenType.Character, 11, "b", 1, 6),
   TeXToken.new(TeXTokenType.Character, 11, "a", 1, 7),
   TeXToken.new(TeXTokenType.Character, 11, "r", 1, 8),
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
