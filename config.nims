task build, "Compile the application into an executable.":
   withDir("src"):
      exec("nim c -d:release --passC:-flto --passL:-s --gc:markAndSweep lins")

   rmFile("lins".toExe)
   mvFile("src/lins".toExe, "lins".toExe)
   setCommand "nop"


task tests, "Run the test suite":
   withDir("tests"):
      exec("nim c -r lexers/tgolden")
   setCommand "nop"


task plaintests, "Run the plain text lexer test suite":
   withDir("tests"):
      exec("nim c -r lexers/tplain")
   setCommand "nop"


task textests, "Run the TeX lexer test suite":
   withDir("tests"):
      exec("nim c -r lexers/ttex")
   setCommand "nop"


task latextests, "Run the LaTeX parser test suite":
   withDir("tests"):
      exec("nim c -r parsers/tlatex")
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

