import streams
import terminal
import strformat

include ../../src/utils/log
include ../../src/linters/linter

var
   nof_passed = 0
   nof_failed = 0


template run_test(title, stimuli: string; reference: string,
                  debug: bool = false) =
   var response = wrap_words(stimuli)
   try:
      if debug:
         echo response
         echo reference
      do_assert(response == reference, "'" & response & "'")
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


run_test("Preserved manual break", """
Hello there. This is a test
to see if linebreaks are preserved.""",
"""
Hello there. This is a test
to see if linebreaks are preserved.""")


run_test("Single line break", """
Try to break up this very long sentence if you can, did I mention it's very long, I mean it could be longer but still.""",
"""
Try to break up this very long sentence if you can, did I mention it's very
long, I mean it could be longer but still.""")


run_test("Line break on very long word", """
Try to break up this very long sentence if you can, didImentionit'sverylongandstuff.""",
"""
Try to break up this very long sentence if you can,
didImentionit'sverylongandstuff.""")


run_test("Preserving indentation", """
Preserving the
 indentation
  of
   these
    words.""",
"""
Preserving the
 indentation
  of
   these
    words.""")


run_test("Preserving indentation, single line break", """
Preserving
  the indentation of this paragraph of text. We began with a sentence which will not be broken, this one will though.""",
"""
Preserving
  the indentation of this paragraph of text. We began with a sentence which will
  not be broken, this one will though.""")


run_test("Word longer than the maximum line width", """
Thisisaverylongwordthatwillbebrokenacrosstwolinesthisfirstpartwillremainherewhilethispartwillberelocatedtothesecondline. Did it work?""",
"""
Thisisaverylongwordthatwillbebrokenacrosstwolinesthisfirstpartwillremainherewhil
ethispartwillberelocatedtothesecondline. Did it work?""")


run_test("Word longer than the maximum line width, with preserved indentation",
"""
Set up indentation block
   thisisaverylongwordthatwillbebrokenacrosstwolinesthisfirstpartwillremainherewhilethispartwillberelocatedtothesecondline.
Back on the first level.""",
"""
Set up indentation block
   thisisaverylongwordthatwillbebrokenacrosstwolinesthisfirstpartwillremainherew
   hilethispartwillberelocatedtothesecondline.
Back on the first level.""")


run_test("Irregular whitespace", """
This is a  sentence   with
   irregular  whitespace.
   We have
     to
   preserve   whatever the  user    has put on the  line.   The user   knows  best.""",
"""
This is a  sentence   with
   irregular  whitespace.
   We have
     to
   preserve   whatever the  user    has put on the  line.   The user   knows
   best.""")


run_test("Unicode", """
abc uitdaeröägfßhydüäpydqfü,träpydqgpmüdträpydföägpydörztdüöäfguiaeowäzjdtrüöäp psnrtuiydrözenrüöäpyfdqazpesnrtulocjtüö
äzydgyqgfqfgprtnwjlcydkqgfüöezmäzydydqüüöäpdtrnvwfhgckdumböäpydfgtdgfhtdrntdrntydfogiayqfguiatrnydrntüöärtniaoeydfgaoeiqfglwcßqfgxvlcwgtfhiaoen
rsüöäapmböäptdrniaoydfglckqfhouenrtsüöäptrniaoeyqfgulocfqclgwxßqflgcwßqfxglcwrniatrnmüböäpmöäbpümöäbpüöämpbaoestnriaesnrtdiaesrtdniaesdrtnaetdr
iaoenvlcyfglwckßqfgvwkßqgfvlwkßqfgvlwckßqvlwkgfUIαοιαοιαχολωχσωχνωκψρχκψρτιεαοσηζϵηζιοεννκεωνιαλωσωκνκψρκγτφγτχκγτεκργτιχνκιωχσιλωσλωχξλξλξωχωχ
ξχλωωχαοεοιαεοαεοιαεοαεοιαοεσναοεκνρκψγκψφϵιηαααοε""",
"""
abc uitdaeröägfßhydüäpydqfü,träpydqgpmüdträpydföägpydörztdüöäfguiaeowäzjdtrüöäp
psnrtuiydrözenrüöäpyfdqazpesnrtulocjtüö
äzydgyqgfqfgprtnwjlcydkqgfüöezmäzydydqüüöäpdtrnvwfhgckdumböäpydfgtdgfhtdrntdrnty
dfogiayqfguiatrnydrntüöärtniaoeydfgaoeiqfglwcßqfgxvlcwgtfhiaoen
rsüöäapmböäptdrniaoydfglckqfhouenrtsüöäptrniaoeyqfgulocfqclgwxßqflgcwßqfxglcwrni
atrnmüböäpmöäbpümöäbpüöämpbaoestnriaesnrtdiaesrtdniaesdrtnaetdr
iaoenvlcyfglwckßqfgvwkßqgfvlwkßqfgvlwckßqvlwkgfUIαοιαοιαχολωχσωχνωκψρχκψρτιεαοση
ζϵηζιοεννκεωνιαλωσωκνκψρκγτφγτχκγτεκργτιχνκιωχσιλωσλωχξλξλξωχωχ
ξχλωωχαοεοιαεοαεοιαεοαεοιαοεσναοεκνρκψγκψφϵιηαααοε""")


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

