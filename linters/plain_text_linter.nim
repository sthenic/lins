import strutils

import ../rules/rules

type
   ViolationCount = tuple
      error: int
      warning: int
      suggestion: int

var
   nof_violations_total: ViolationCount
   nof_violations_file: ViolationCount
   nof_files: int

proc print_violation(v: Violation) =
   discard

