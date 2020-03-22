version = "0.6.1"
author = "Marcus Eriksson"
description = "Lins is a lightweight, extensible linter for prose."
license = "MIT"
src_dir = "src"
bin = @["lins"]
skip_ext = @["nim", "txt"]

# Dependencies
requires "nim >= 1.0.0"
requires "yaml >= 0.13.0"

# Tasks
task build_release, "Compile the application into an executable (release mode, don't install)":
   exec("nimble build -d:release")


task build_release_xwin64, "Cross-compile the application into a Windows executable with MinGW (release mode, don't install)":
   exec("nimble build -d:release --os:windows -d:xwin")


task test, "Run the test suite.":
   exec("nimble install -d")
   exec("nimble lexertests")
   exec("nimble parsertests")
   exec("nimble utilstests")
   exec("nimble lintertests")


task lexertests, "Run the lexer test suite.":
   with_dir("tests/lexers"):
      exec("nim c --hints:off -r tplain")
      exec("nim c --hints:off -r ttex")


task parsertests, "Run the parser test suite.":
   with_dir("tests/parsers"):
      exec("nim c --hints:off -r tplain")
      exec("nim c --hints:off -r tlatex")


task utilstests, "Run the utils test suite.":
   with_dir("tests/utils"):
      exec("nim c --hints:off -r twordwrap")


task lintertests, "Run the linter test suite.":
   with_dir("tests/linters"):
      exec("nim c --hints:off -r tlatex")
