task build, "Compile the application into an executable.":
   withDir("src"):
      exec("nim c -d:release --passC:-flto --passL:-s --gc:markAndSweep lins")

   rmFile("lins".toExe)
   mvFile("src/lins".toExe, "lins".toExe)
   setCommand "nop"


task buildxwin64, "Cross-compile the application into an executable for 64-bit Windows.":
   withDir("src"):
      exec("nim c -d:release --os:windows -d:xwin --passC:-flto --passL:-s --gc:markAndSweep lins")

   rmFile("lins.exe")
   mvFile("src/lins.exe", "lins.exe")
   setCommand "nop"


task buildxmac64, "Cross-compile the application into an executable for 64-bit Mac OSX.":
   withDir("src"):
      exec("nim c -d:release --os:macosx -d:xmac --passC:-flto --passL:-s --gc:markAndSweep lins")

   rmFile("lins")
   mvFile("src/lins", "lins")
   setCommand "nop"


task debug, "Compile the application with debugging trace messages active":
   withDir("src"):
      exec("nim c lins")

   rmFile("lins".toExe)
   mvFile("src/lins".toExe, "lins".toExe)
   setCommand "nop"


task tests, "Run all tests":
   --r
   --verbosity:0
   setCommand "c", "tests/all"
