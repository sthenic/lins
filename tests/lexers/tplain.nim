import streams
import terminal
import strformat

include ../../src/lexers/plain_lexer

var
   response: seq[string] = @[]
   nof_passed = 0
   nof_failed = 0


template run_test(title, stimuli: string; reference: seq[PlainToken],
                  debug: bool = false) =
   var response: seq[PlainToken] = @[]
   var lex: PlainLexer
   var tok: PlainToken
   init(tok)
   open_lexer(lex, "test", new_string_stream(stimuli))
   while true:
      get_token(lex, tok)
      if tok.token_type == PlainTokenType.EndOfFile:
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
   except AssertionDefect:
      styledWriteLine(stdout, styleBright, fgRed, "[✗] ",
                      fgWhite, "Test '",  title, "'")
      nof_failed += 1
   except IndexDefect:
      styledWriteLine(stdout, styleBright, fgRed, "[✗] ",
                      fgWhite, "Test '",  title, "'", #resetStyle,
                      " (missing reference data)")
      nof_failed += 1


run_test("Pangram: English",
"""The quick brown fox jumps over the lazy dog.""", @[
   PlainToken.new(Character, "T", 1, 0),
   PlainToken.new(Character, "h", 1, 1),
   PlainToken.new(Character, "e", 1, 2),
   PlainToken.new(Character, " ", 1, 3),
   PlainToken.new(Character, "q", 1, 4),
   PlainToken.new(Character, "u", 1, 5),
   PlainToken.new(Character, "i", 1, 6),
   PlainToken.new(Character, "c", 1, 7),
   PlainToken.new(Character, "k", 1, 8),
   PlainToken.new(Character, " ", 1, 9),
   PlainToken.new(Character, "b", 1, 10),
   PlainToken.new(Character, "r", 1, 11),
   PlainToken.new(Character, "o", 1, 12),
   PlainToken.new(Character, "w", 1, 13),
   PlainToken.new(Character, "n", 1, 14),
   PlainToken.new(Character, " ", 1, 15),
   PlainToken.new(Character, "f", 1, 16),
   PlainToken.new(Character, "o", 1, 17),
   PlainToken.new(Character, "x", 1, 18),
   PlainToken.new(Character, " ", 1, 19),
   PlainToken.new(Character, "j", 1, 20),
   PlainToken.new(Character, "u", 1, 21),
   PlainToken.new(Character, "m", 1, 22),
   PlainToken.new(Character, "p", 1, 23),
   PlainToken.new(Character, "s", 1, 24),
   PlainToken.new(Character, " ", 1, 25),
   PlainToken.new(Character, "o", 1, 26),
   PlainToken.new(Character, "v", 1, 27),
   PlainToken.new(Character, "e", 1, 28),
   PlainToken.new(Character, "r", 1, 29),
   PlainToken.new(Character, " ", 1, 30),
   PlainToken.new(Character, "t", 1, 31),
   PlainToken.new(Character, "h", 1, 32),
   PlainToken.new(Character, "e", 1, 33),
   PlainToken.new(Character, " ", 1, 34),
   PlainToken.new(Character, "l", 1, 35),
   PlainToken.new(Character, "a", 1, 36),
   PlainToken.new(Character, "z", 1, 37),
   PlainToken.new(Character, "y", 1, 38),
   PlainToken.new(Character, " ", 1, 39),
   PlainToken.new(Character, "d", 1, 40),
   PlainToken.new(Character, "o", 1, 41),
   PlainToken.new(Character, "g", 1, 42),
   PlainToken.new(Character, ".", 1, 43),
])


run_test("Paragraph break",
"""The quick brown
fox jumps over

the lazy dog.""", @[
   PlainToken.new(Character, "T", 1, 0),
   PlainToken.new(Character, "h", 1, 1),
   PlainToken.new(Character, "e", 1, 2),
   PlainToken.new(Character, " ", 1, 3),
   PlainToken.new(Character, "q", 1, 4),
   PlainToken.new(Character, "u", 1, 5),
   PlainToken.new(Character, "i", 1, 6),
   PlainToken.new(Character, "c", 1, 7),
   PlainToken.new(Character, "k", 1, 8),
   PlainToken.new(Character, " ", 1, 9),
   PlainToken.new(Character, "b", 1, 10),
   PlainToken.new(Character, "r", 1, 11),
   PlainToken.new(Character, "o", 1, 12),
   PlainToken.new(Character, "w", 1, 13),
   PlainToken.new(Character, "n", 1, 14),
   PlainToken.new(Character, " ", 1, 15),
   PlainToken.new(Character, "f", 2, 0),
   PlainToken.new(Character, "o", 2, 1),
   PlainToken.new(Character, "x", 2, 2),
   PlainToken.new(Character, " ", 2, 3),
   PlainToken.new(Character, "j", 2, 4),
   PlainToken.new(Character, "u", 2, 5),
   PlainToken.new(Character, "m", 2, 6),
   PlainToken.new(Character, "p", 2, 7),
   PlainToken.new(Character, "s", 2, 8),
   PlainToken.new(Character, " ", 2, 9),
   PlainToken.new(Character, "o", 2, 10),
   PlainToken.new(Character, "v", 2, 11),
   PlainToken.new(Character, "e", 2, 12),
   PlainToken.new(Character, "r", 2, 13),
   PlainToken.new(Character, " ", 2, 14),
   PlainToken.new(ParagraphBreak, "", 3, 0),
   PlainToken.new(Character, "t", 4, 0),
   PlainToken.new(Character, "h", 4, 1),
   PlainToken.new(Character, "e", 4, 2),
   PlainToken.new(Character, " ", 4, 3),
   PlainToken.new(Character, "l", 4, 4),
   PlainToken.new(Character, "a", 4, 5),
   PlainToken.new(Character, "z", 4, 6),
   PlainToken.new(Character, "y", 4, 7),
   PlainToken.new(Character, " ", 4, 8),
   PlainToken.new(Character, "d", 4, 9),
   PlainToken.new(Character, "o", 4, 10),
   PlainToken.new(Character, "g", 4, 11),
   PlainToken.new(Character, ".", 4, 12),
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
