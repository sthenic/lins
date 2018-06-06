
task build, "Compile the application into an executable.":
   exec("nim c -d:release --passC:-flto --passL:-s --gc:markAndSweep lins")
   setCommand "nop"

task debug, "Compile the application with debugging trace messages active":
   setCommand "c", "lins"

task tests, "Run all tests":
   --r
   --verbosity:0
   setCommand "c", "tests/all"
