task build, "Compile the application into an executable.":
   withDir("src"):
      exec("nim c -d:release --multimethods:on --warning[LockLevel]:off --passC:-flto --passL:-s --gc:markAndSweep lins")

   rmFile("lins".toExe)
   mvFile("src/lins".toExe, "lins".toExe)
   setCommand "nop"


task tests, "Run the test suite":
   exec("nim lexertests")
   exec("nim parsertests")
   exec("nim utilstests")
   setCommand "nop"


task lexertests, "Run the lexer test suite":
   withDir("tests/lexers"):
      exec("nim c -r tplain")
      exec("nim c -r ttex")
   setCommand "nop"


task parsertests, "Run the parser test suite":
   withDir("tests/parsers"):
      exec("nim c -r tplain")
      exec("nim c -r tlatex")
   setCommand "nop"


task utilstests, "Run the linter test suite":
   withDir("tests/utils"):
      exec("nim c -r twordwrap")
   setCommand "nop"


task buildxwin64, "Compile the application into an executable.":
   withDir("src"):
      exec("nim c -d:release --multimethods:on --warning[LockLevel]:off --os:windows -d:xwin --passC:-flto --passL:-s --gc:markAndSweep lins")

   rmFile("lins.exe")
   mvFile("src/lins.exe", "lins.exe")
   setCommand "nop"


task debug, "Compile the application with debugging trace messages active":
   withDir("src"):
      exec("nim c --multimethods:on --warning[LockLevel]:off lins")

   rmFile("lins".toExe)
   mvFile("src/lins".toExe, "lins".toExe)
   setCommand "nop"

