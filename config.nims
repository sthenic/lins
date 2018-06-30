
task build, "Compile the application into an executable.":
   withDir("src"):
      exec("nim c -d:release --passC:-flto --passL:-s --gc:markAndSweep lins")

   mvFile("src/lins".toExe, "lins".toExe)
   setCommand "nop"

task debug, "Compile the application with debugging trace messages active":
   withDir("src"):
      exec("nim c lins")

   mvFile("src/lins".toExe, "lins".toExe)
   setCommand "nop"

task tests, "Run all tests":
   --r
   --verbosity:0
   setCommand "c", "tests/all"
