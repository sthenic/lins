import nre
import unicode
import strutils
import tables

import ../lexers/plain_text_lexer
import ../utils/log

type
   EnforceError = object of Exception
   EnforceNotImplementedError = object of Exception

type
   Severity* = enum
      SUGGESTION
      WARNING
      ERROR

   Scope* = enum
      TEXT
      SENTENCE
      PARAGRAPH

   Limit* = enum
      MIN
      MAX

   Position = tuple
      row, col: int

   Violation* = tuple
      kind: string
      severity: Severity
      severity_str: string
      source_file: string
      message: string
      position: Position

   Rule* = ref object of RootObj
      kind: string
      severity: Severity
      message: string
      source_file: string

   RuleExistence* = ref object of Rule
      regex: Regex

   RuleSubstitution* = ref object of Rule
      regex: Regex
      subst_table: Table[string, string]

   RuleOccurrence* = ref object of Rule
      regex: Regex
      limit_val: int
      limit_kind: Limit
      scope: Scope
      nof_matches: int
      par_prev: int
      has_alerted: bool

   RuleRepetition* = ref object of Rule
      regex: Regex
      scope: Scope
      par_prev: int
      nof_matches: int

   RuleConsistency* = ref object of Rule
      regex_first: Regex
      regex_second: Regex
      scope: Scope
      par_prev: int
      nof_matches_first: int
      nof_matches_second: int

   RuleDefinition* = ref object of Rule
      regex_def: Regex
      regex_decl: Regex
      exceptions: seq[string]
      scope: Scope
      definitions: Table[string, Position]
      par_prev: int

   RuleConditional* = ref object of Rule
      regex_first: Regex
      regex_second: Regex
      scope: Scope
      par_prev: int
      second_observed: bool


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

proc create_violation(r: Rule, pos: Position,
                      message_args: varargs[string]): Violation =
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

method enforce*(r: Rule, sentence: Sentence): seq[Violation] {.base.}  =
   raise new_exception(EnforceNotImplementedError,
                       "Rule enforcement not implemented for rule '" &
                       r.kind & "'.")

proc new*(t: typedesc[RuleExistence], severity: Severity, message: string,
          source_file: string, regex: string, ignore_case: bool): RuleExistence =
   var regex_flags = ""
   if ignore_case:
      regex_flags = "(?i)"

   return RuleExistence(kind: "existence", severity: severity, message: message,
                        source_file: source_file,
                        regex: re(regex_flags & regex))

method enforce*(r: RuleExistence, sentence: Sentence): seq[Violation] =
   var violations: seq[Violation] = @[]

   for m in nre.find_iter($sentence.str, r.regex):
      let violation_pos = r.calculate_position(sentence.row_begin,
                                               sentence.col_begin,
                                               m.match_bounds.a + 1,
                                               sentence.newlines)

      violations.add(r.create_violation(violation_pos, $m))

   return violations


proc new*(t: typedesc[RuleSubstitution], severity: Severity, message: string,
          source_file: string, regex: string, subst_table: Table[string, string],
          ignore_case: bool): RuleSubstitution =
   var regex_flags = ""
   if ignore_case:
      regex_flags = "(?i)"

   var lsubst_table = init_table[string, string]()
   for key, value in pairs(subst_table):
      lsubst_table[regex_flags & key] = value

   return RuleSubstitution(kind: "substitution", severity: severity,
                           message: message, source_file: source_file,
                           regex: re(regex_flags & regex),
                           subst_table: lsubst_table)


method enforce*(r: RuleSubstitution, sentence: Sentence): seq[Violation] =
   var violations: seq[Violation] = @[]

   for m in nre.find_iter($sentence.str, r.regex):
      let mpos = m.match_bounds.a
      let violation_pos = r.calculate_position(sentence.row_begin,
                                               sentence.col_begin,
                                               mpos + 1,
                                               sentence.newlines)
      # If we have found a match, we have to do a costly search through the
      # substitution table in search of a key (an uncompiled regex string)
      # that will yield a match achored at the position reported above.
      # TODO: Improve the LUT. If pre-compiled regexes cannot be used as hashed
      # keys then maybe an array of tuples can be used. Also, if there is any
      # ambiguity in the keys, i.e. two keys would match at the current
      # position, it is undefined which substitution will be recommended.
      var subst = ""
      for key, value in pairs(r.subst_table):
         if is_some(nre.match($sentence.str, re(key), mpos)):
            subst = value
            break

      violations.add(r.create_violation(violation_pos, subst, $m))

   return violations

proc new*(t: typedesc[RuleOccurrence], severity: Severity, message: string,
          source_file: string, regex: string, limit_val: int, limit_kind: Limit,
          scope: Scope, ignore_case: bool): RuleOccurrence =
   var regex_flags = ""
   if ignore_case:
      regex_flags = "(?i)"

   return RuleOccurrence(kind: "occurrence",
                         severity: severity,
                         message: message,
                         source_file: source_file,
                         regex: re(regex_flags & regex),
                         limit_val: limit_val,
                         limit_kind: limit_kind,
                         scope: scope,
                         nof_matches: 0,
                         par_prev: 0,
                         has_alerted: false)


method enforce*(r: RuleOccurrence, sentence: Sentence): seq[Violation] =
   var violations: seq[Violation] = @[]

   # Reset the match counter and alert status depending on the scope.
   case r.scope
   of SENTENCE:
      r.nof_matches = 0
      r.has_alerted = false
   of PARAGRAPH:
      if not (r.par_prev == sentence.par_idx):
         r.nof_matches = 0
         r.has_alerted = false
   else:
      discard

   for m in nre.find_iter($sentence.str, r.regex):
      # Count the match (pre-incrementation).
      r.nof_matches += 1

      # Check against the specified maximum limit. If the value is out of
      # bounds, we create a violation object, set the alert status and
      # break to avoid unnecessary loop iterations.
      if (not r.has_alerted and
          (r.limit_kind == MAX) and (r.nof_matches > r.limit_val)):
         let sentence_pos = (sentence.row_begin, sentence.col_begin)
         violations.add(r.create_violation(sentence_pos))
         break

   # Check against the specified minimum limit. This is only supported in
   # the sentence scope.
   if (not r.has_alerted and
       (r.limit_kind == MIN) and (r.nof_matches < r.limit_val)):
      let sentence_pos = (sentence.row_begin, sentence.col_begin)
      violations.add(r.create_violation(sentence_pos))

   # Remember the paragraph.
   r.par_prev = sentence.par_idx

   return violations


proc new*(t: typedesc[RuleRepetition], severity: Severity, message: string,
          source_file: string, regex: string, scope: Scope,
          ignore_case: bool): RuleRepetition =
   var regex_flags = ""
   if ignore_case:
      regex_flags = "(?i)"

   return RuleRepetition(kind: "repetition",
                         severity: severity,
                         message: message,
                         source_file: source_file,
                         regex: re(regex_flags & regex),
                         scope: scope,
                         nof_matches: 0,
                         par_prev: 0)


method enforce*(r: RuleRepetition, sentence: Sentence): seq[Violation] =
   var violations: seq[Violation] = @[]

   case r.scope
   of SENTENCE:
      r.nof_matches = 0
   of PARAGRAPH:
      if not (r.par_prev == sentence.par_idx):
         r.nof_matches = 0
   else:
      discard

   for m in nre.find_iter($sentence.str, r.regex):
      r.nof_matches += 1

      if (r.nof_matches > 1):
         let violation_pos = r.calculate_position(sentence.row_begin,
                                                  sentence.col_begin,
                                                  m.match_bounds.a + 1,
                                                  sentence.newlines)

         violations.add(r.create_violation(violation_pos, $m))

   # Remember the paragraph.
   r.par_prev = sentence.par_idx

   return violations


proc new*(t: typedesc[RuleConsistency], severity: Severity, message: string,
          source_file: string, regex_first: string, regex_second: string,
          scope: Scope, ignore_case: bool): RuleConsistency =
   var regex_flags = ""
   if ignore_case:
      regex_flags = "(?i)"

   return RuleConsistency(kind: "consistency",
                         severity: severity,
                         message: message,
                         source_file: source_file,
                         regex_first: re(regex_flags & regex_first),
                         regex_second: re(regex_flags & regex_second),
                         scope: scope,
                         nof_matches_first: 0,
                         nof_matches_second: 0,
                         par_prev: 0)


method enforce*(r: RuleConsistency, sentence: Sentence): seq[Violation] =
   var violations: seq[Violation] = @[]

   # Reset the match counter and alert status depending on the scope.
   case r.scope
   of SENTENCE:
      r.nof_matches_first = 0
      r.nof_matches_second = 0
   of PARAGRAPH:
      if not (r.par_prev == sentence.par_idx):
         r.nof_matches_first = 0
         r.nof_matches_second = 0
   else:
      discard

   # TODO: Fix implementation to be able to resolve in-sentence occurrences of
   # both expressions. Which one is first etc.

   # Analyze matches for the first regex.
   for m in nre.find_iter($sentence.str, r.regex_first):
      r.nof_matches_first += 1

      if (r.nof_matches_second > 0):
         let violation_pos = r.calculate_position(sentence.row_begin,
                                                  sentence.col_begin,
                                                  m.match_bounds.a + 1,
                                                  sentence.newlines)

         violations.add(r.create_violation(violation_pos, $m))

   # Analyze matches for the second regex.
   for m in nre.find_iter($sentence.str, r.regex_second):
      r.nof_matches_second += 1

      if (r.nof_matches_first > 0):
         let violation_pos = r.calculate_position(sentence.row_begin,
                                                  sentence.col_begin,
                                                  m.match_bounds.a + 1,
                                                  sentence.newlines)

         violations.add(r.create_violation(violation_pos, $m))

   # Remember the paragraph.
   r.par_prev = sentence.par_idx

   return violations

# Regexes should be auto-filled on an above level. Drafts are:
#   regex_def = r'(?:\b[A-Z][a-z]+ )+\(([A-Z]{3,5})\)'
#   regex_decl = r'\b([A-Z]{3,5})\b'
proc new*(t: typedesc[RuleDefinition], severity: Severity, message: string,
          source_file: string, regex_def: string, regex_decl: string,
          exceptions: seq[string], scope: Scope,
          ignore_case: bool): RuleDefinition =
   var regex_flags = ""
   if ignore_case:
      regex_flags = "(?i)"

   return RuleDefinition(kind: "definition",
                         severity: severity,
                         message: message,
                         source_file: source_file,
                         regex_def: re(regex_flags & regex_def),
                         regex_decl: re(regex_flags & regex_decl),
                         exceptions: exceptions,
                         scope: scope,
                         definitions: init_table[string, Position](),
                         par_prev: 0)


method enforce*(r: RuleDefinition, sentence: Sentence): seq[Violation] =
   var violations: seq[Violation] = @[]

   # Reset the match counter and alert status depending on the scope.
   case r.scope
   of SENTENCE:
      r.definitions.clear()
   of PARAGRAPH:
      if not (r.par_prev == sentence.par_idx):
         r.definitions.clear()
   else:
      discard

   # Go through the sentence looking for definitions. Store the position to
   # make sure we can differentiate the order of definitions and
   # declarations within a sentence.
   for m_def in nre.find_iter($sentence.str, r.regex_def):
      try:
         let def = m_def.captures[0]
         let pos = r.calculate_position(sentence.row_begin,
                                        sentence.col_begin,
                                        m_def.capture_bounds[0].get.a + 1,
                                        sentence.newlines)

         if r.definitions.has_key_or_put(def, pos):
            # TODO: Insert this warning message into a custom violation and
            #       add that to the sequence.
            log.warning("Redefinition of '$#' at $#:$#.",
                        def, $pos.row, $pos.col)

      except IndexError:
         # Abort if no capture group can be found. This should not happen due
         # to validation enforced at an earlier stage.
         log.error("No capture group defined for declaration in file '$#'. " &
                   "This should not have occurred.", r.source_file)
         raise new_exception(EnforceError, "No capture group defined.")

   # Run through the sentence looking for declarations. If the declaration
   # has no definition, the rule is violated outright. Otherwise, we have
   # to double-check the position of the declaration in relation to the
   # definition. We skip any declarations in the exception list.
   for m_decl in nre.find_iter($sentence.str, r.regex_decl):
      try:
         let decl = m_decl.captures[0]
         if decl in r.exceptions:
            continue

         let (row_decl, col_decl) =
            r.calculate_position(sentence.row_begin, sentence.col_begin,
                                 m_decl.capture_bounds[0].get.a + 1,
                                 sentence.newlines)

         var is_violated = false
         if not r.definitions.has_key(decl):
            is_violated = true
         else:
            let (row_def, col_def) = r.definitions[decl]

            if (row_def == row_decl and col_def > col_decl or
                row_def > row_decl):
               is_violated = true

         if is_violated:
            # TODO: Fix the Position type, maybe a raw tuple instead
            # let pos: Position = (row: row_decl, col: col_decl)
            violations.add(r.create_violation((row_decl, col_decl), decl))


      except IndexError:
         # Abort if no capture group can be found. This should not happen due
         # to validation enforced at an earlier stage.
         log.error("No capture group defined for definition in file '$#'. " &
                   "This should not have occurred.", r.source_file)
         raise new_exception(EnforceError, "No capture group defined.")

   # Remember the paragraph.
   r.par_prev = sentence.par_idx

   return violations


proc new*(t: typedesc[RuleConditional], severity: Severity, message: string,
          source_file: string, regex_first: string, regex_second: string,
          scope: Scope, ignore_case: bool): RuleConditional =
   var regex_flags = ""
   if ignore_case:
      regex_flags = "(?i)"

   return RuleConditional(kind: "conditional",
                          severity: severity,
                          message: message,
                          source_file: source_file,
                          regex_first: re(regex_flags & regex_first),
                          regex_second: re(regex_flags & regex_second),
                          scope: scope,
                          par_prev: 0,
                          second_observed: false)


method enforce*(r: RuleConditional, sentence: Sentence): seq[Violation] =
   var violations: seq[Violation] = @[]

   # Reset the match counter and alert status depending on the scope.
   case r.scope
   of SENTENCE:
      r.second_observed = false
   of PARAGRAPH:
      if not (r.par_prev == sentence.par_idx):
         r.second_observed = false
   else:
      discard

   var
      row_second = 0
      col_second = 0

   let m_second = nre.find($sentence.str, r.regex_second)
   if not is_none(m_second) and not r.second_observed:
      try:
         (row_second, col_second) =
            r.calculate_position(sentence.row_begin, sentence.col_begin,
                                 m_second.get.capture_bounds[0].get.a + 1,
                                 sentence.newlines)

         r.second_observed = true

      except IndexError:
         # Abort if no capture group can be found. This should not happen due
         # to validation enforced at an earlier stage.
         log.error("No capture group defined for conditional in file '$#'. " &
                   "This should not have occurred.", r.source_file)
         raise new_exception(EnforceError, "No capture group defined.")

   for m_first in nre.find_iter($sentence.str, r.regex_first):
      let (row_first, col_first) =
         r.calculate_position(sentence.row_begin, sentence.col_begin,
                              m_first.match_bounds.a + 1, # TODO: Group here?
                              sentence.newlines)
      if (not r.second_observed or
          (row_second == row_first and col_second > col_first) or
          (row_second > row_first)):
         violations.add(r.create_violation((row_first, col_first), $m_first))

   # Remember the paragraph.
   r.par_prev = sentence.par_idx

   return violations
