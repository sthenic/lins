version = "0.7.0"
author = "Marcus Eriksson"
description = "Lins is a lightweight, extensible linter for prose."
license = "MIT"
src_dir = "src"
bin = @["lins"]
skip_ext = @["nim", "txt"]

# Dependencies
requires "nim >= 1.6.0"
requires "yaml >= 0.16.0"

# Tasks
task build_release, "Compile the application into an executable (release mode, don't install)":
   exec("nimble build -d:release --gc:orc")


task build_release_xwin64, "Cross-compile the application into a Windows executable with MinGW (release mode, don't install)":
   exec("nimble build -d:release --os:windows -d:xwin --gc:orc")


task test, "Run the test suite.":
   exec("nimble install -d")
   exec("nimble lexertests")
   exec("nimble parsertests")
   exec("nimble utilstests")
   exec("nimble lintertests")


task lexertests, "Run the lexer test suite.":
   with_dir("tests/lexers"):
      exec("nim c --hints:off --gc:orc -r tplain")
      exec("nim c --hints:off --gc:orc -r ttex")


task parsertests, "Run the parser test suite.":
   with_dir("tests/parsers"):
      exec("nim c --hints:off --gc:orc -r tplain")
      exec("nim c --hints:off --gc:orc -r tlatex")


task utilstests, "Run the utils test suite.":
   with_dir("tests/utils"):
      exec("nim c --hints:off --gc:orc -r twordwrap")
      exec("nim c --hints:off --gc:orc -r tconfiguration")


task lintertests, "Run the linter test suite.":
   with_dir("tests/linters"):
      exec("nim c --hints:off --gc:orc -r tlatex")
