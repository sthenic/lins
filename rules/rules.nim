import nre
import unicode
import strutils

import ../lexers/plain_text

type
   Severity* = enum
      SUGGESTION
      WARNING
      ERROR

   Scope* = enum
      TEXT
      SENTENCE
      PARAGRAPH

   Position = tuple
      row, col: int

   Violation* = tuple
      kind: string
      severity: Severity
      severity_str: string
      source_file: string
      message: string
      position: Position

   Rule = ref object of RootObj
      kind: string
      severity: Severity
      message: string
      source_file: string

# Constructors
proc new*(t: typedesc[Rule], kind: string, severity: Severity, message: string,
          source_file: string): Rule =
   Rule(kind: kind, severity: severity, message: message,
        source_file: source_file)

proc create_severity_string(r: Rule): string =
   var tmp = ""
   case r.severity
   of SUGGESTION:
      tmp = "\x1B[1;34msuggestion\x1B[0m"
   of WARNING:
      tmp = "\x1B[1;33mwarning\x1B[0m"
   of ERROR:
      tmp = "\x1B[1;31merror\x1B[0m"
   else:
      echo "ERROR!"

   return tmp

# TODO: Fix type of message args and format the message with the arguments.
proc create_violation(r: Rule, pos: Position, message_args: varargs[string]): Violation =
   (kind: r.kind, severity: r.severity,
    severity_str: r.create_severity_string(), source_file: r.source_file,
    message: format(r.message, message_args), position: pos)

# Compute absolute file position of the rule violation using the absolute
# sentence position, the relative rule violation position within the
# sentence (one-dimensional) and the (original) newline positions within the
# sencence.
proc calculate_position(r: Rule, row_begin, col_begin: int,
                        offset_violation: int, newlines: seq[int]): Position =
   if newlines.len == 0:
      return (row_begin, col_begin + offset_violation - 1)
   else:
      var
         i = 0
         offset_closest_newline = 0
         col = col_begin + offset_violation - 1

      while newlines[i] <= offset_violation:
         offset_closest_newline = newlines[i]
         col = offset_violation

         i += 1
         if i == newlines.len:
            break

      return (row_begin + i, col - offset_closest_newline)

# TODO: Raise exception
proc enforce*(r: Rule): seq[Violation] =
   echo "ENFORCE NOT IMPLEMENTED FOR RULE!", r.kind

# Rule 'existence'
type
   RuleExistence* = ref object of Rule
      regex: Regex

proc new*(t: typedesc[RuleExistence], severity: Severity, message: string,
          source_file: string, regex: string, ignore_case: bool): RuleExistence =
   var regex_flags = ""
   if ignore_case:
      regex_flags = "(?i)"

   return RuleExistence(kind: "existence", severity: severity, message: message,
                        source_file: source_file, regex: re(regex_flags & regex))

proc enforce*(r: RuleExistence, sentence: Sentence): seq[Violation] =
   var violations: seq[Violation] = @[]

   for m in nre.find_iter($sentence.str, r.regex):
      let violation_pos = r.calculate_position(sentence.row_begin,
                                               sentence.col_begin,
                                               m.match_bounds.a + 1,
                                               sentence.newlines)

      violations.add(r.create_violation(violation_pos, $m))

   return violations

