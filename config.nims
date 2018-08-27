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

