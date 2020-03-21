task build, "Compile the application into an executable.":
   withDir("src"):
      exec("nim c -d:release --passC:-flto --passL:-s --gc:markAndSweep lins")

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
      exec("nim c --hints:off -r tplain")
      exec("nim c --hints:off -r ttex")
   setCommand "nop"


task parsertests, "Run the parser test suite":
   withDir("tests/parsers"):
      exec("nim c --hints:off -r tplain")
      exec("nim c --hints:off -r tlatex")
   setCommand "nop"


task utilstests, "Run the linter test suite":
   withDir("tests/utils"):
      exec("nim c --hints:off -r twordwrap")
   setCommand "nop"


task buildxwin64, "Compile the application into an executable.":
   withDir("src"):
      exec("nim c -d:release --os:windows -d:xwin --passC:-flto --passL:-s --gc:markAndSweep lins")

   rmFile("lins.exe")
   mvFile("src/lins.exe", "lins.exe")
   setCommand "nop"


task debug, "Compile the application with debugging trace messages active":
   withDir("src"):
      exec("nim c lins")

   rmFile("lins".toExe)
   mvFile("src/lins".toExe, "lins".toExe)
   setCommand "nop"

