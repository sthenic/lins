import nre
import unicode
import strutils
import tables

import ../lexers/plain_lexer
import ../utils/log

type
   EnforceError = object of Exception
   EnforceNotImplementedError = object of Exception

type
   Severity* = enum
      ERROR
      WARNING
      SUGGESTION

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
      source_file: string
      message: string
      position: Position
      display_name: string

   Rule* = ref object of RootObj
      kind*: string
      severity*: Severity
      message*: string
      source_file*: string
      display_name*: string
      ignore_case*: bool

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
      matches: Table[string, int]

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
      first_observed: bool


# Constructors
proc new*(t: typedesc[Rule], kind: string, severity: Severity, message: string,
          source_file: string, display_name: string): Rule =
   Rule(kind: kind, severity: severity, message: message,
        source_file: source_file, display_name: display_name)


proc create_violation(r: Rule, pos: Position,
                      message_args: varargs[string]): Violation =
   (kind: r.kind, severity: r.severity, source_file: r.source_file,
    message: format(r.message, message_args), position: pos,
    display_name: r.display_name)

# Compute absolute file position of the rule violation using the absolute
# sentence position, the relative rule violation position within the
# sentence (one-dimensional) and the (original) newline positions within the
# sencence.
proc calculate_position(r: Rule, row_begin, col_begin: int,
                        offset_violation: int,
                        offset_pts: seq[tuple[pos, row, col: int]]): Position =
   if offset_pts.len == 0:
      return (row_begin, col_begin + offset_violation - 1)
   else:
      var
         i = 0
         offset_closest_newline = 0
         col = col_begin + offset_violation - 1
         row = row_begin

      while offset_pts[i].pos <= offset_violation:
         offset_closest_newline = offset_pts[i].pos
         col = offset_violation + offset_pts[i].col
         row += offset_pts[i].row

         i += 1
         if i == offset_pts.len:
            break

      return (row, col - offset_closest_newline)


method enforce*(r: Rule, sentence: Sentence): seq[Violation] {.base.}  =
   log.abort(EnforceNotImplementedError,
             "Rule enforcement not implemented for rule '$#'.", r.kind)

proc new*(t: typedesc[RuleExistence], severity: Severity, message: string,
          source_file: string, display_name: string, regex: string,
          ignore_case: bool): RuleExistence =
   var regex_flags = ""
   if ignore_case:
      regex_flags = "(?i)"

   return RuleExistence(kind: "existence",
                        severity: severity,
                        message: message,
                        source_file: source_file,
                        display_name: display_name,
                        ignore_case: ignore_case,
                        regex: re(regex_flags & regex))

method enforce*(r: RuleExistence, sentence: Sentence): seq[Violation] =
   var violations: seq[Violation] = @[]

   for m in nre.find_iter($sentence.str, r.regex):
      let violation_pos = r.calculate_position(sentence.row_begin,
                                               sentence.col_begin,
                                               m.match_bounds.a + 1,
                                               sentence.offset_pts)

      violations.add(r.create_violation(violation_pos, $m))

   return violations


proc new*(t: typedesc[RuleSubstitution], severity: Severity, message: string,
          source_file: string, display_name: string, regex: string,
          subst_table: Table[string, string],
          ignore_case: bool): RuleSubstitution =
   var regex_flags = ""
   if ignore_case:
      regex_flags = "(?i)"

   var lsubst_table = init_table[string, string]()
   for key, value in pairs(subst_table):
      lsubst_table[regex_flags & key] = value

   return RuleSubstitution(kind: "substitution",
                           severity: severity,
                           message: message,
                           source_file: source_file,
                           display_name: display_name,
                           ignore_case: ignore_case,
                           regex: re(regex_flags & regex),
                           subst_table: lsubst_table)


method enforce*(r: RuleSubstitution, sentence: Sentence): seq[Violation] =
   var violations: seq[Violation] = @[]

   for m in nre.find_iter($sentence.str, r.regex):
      let mpos = m.match_bounds.a
      let violation_pos = r.calculate_position(sentence.row_begin,
                                               sentence.col_begin,
                                               mpos + 1,
                                               sentence.offset_pts)
      # If we have found a match, we have to do a costly search through the
      # substitution table in search of a key (an uncompiled regex string)
      # that will yield a match achored at the position reported above. If the
      # match is identical to the substitution, we don't report a violation.
      # This allows the user to define more flexible regexes, for example
      #   analog[ -]to[ -]digital: analog-to-digital
      # allows coverage of all error combinations with one single regex but
      # also covers the correct case, which the substitution protects against.

      # TODO: Improve the LUT. If pre-compiled regexes cannot be used as hashed
      # keys then maybe an array of tuples can be used. Also, if there is any
      # ambiguity in the keys, i.e. two keys would match at the current
      # position, it is undefined which substitution will be recommended.
      var
         subst = ""
         m_str = $m
      if r.ignore_case:
         m_str = to_lower_ascii(m_str)
      for key, value in pairs(r.subst_table):
         var value_str = value
         if r.ignore_case:
            value_str = to_lower_ascii(value)
         if is_some(nre.match($sentence.str, re(key), mpos)) and
               (m_str != value_str):
            subst = value
            break

      if subst != "":
         violations.add(r.create_violation(violation_pos, $m, subst))

   return violations

proc new*(t: typedesc[RuleOccurrence], severity: Severity, message: string,
          source_file: string,  display_name: string, regex: string,
          limit_val: int, limit_kind: Limit, scope: Scope,
          ignore_case: bool): RuleOccurrence =
   var regex_flags = ""
   if ignore_case:
      regex_flags = "(?i)"

   return RuleOccurrence(kind: "occurrence",
                         severity: severity,
                         message: message,
                         source_file: source_file,
                         display_name: display_name,
                         ignore_case: ignore_case,
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
          source_file: string,  display_name: string, regex: string,
          scope: Scope, ignore_case: bool): RuleRepetition =
   var regex_flags = ""
   if ignore_case:
      regex_flags = "(?i)"

   return RuleRepetition(kind: "repetition",
                         severity: severity,
                         message: message,
                         source_file: source_file,
                         display_name: display_name,
                         ignore_case: ignore_case,
                         regex: re(regex_flags & regex),
                         scope: scope,
                         par_prev: 0,
                         matches: init_table[string, int]())


method enforce*(r: RuleRepetition, sentence: Sentence): seq[Violation] =
   var violations: seq[Violation] = @[]

   case r.scope
   of SENTENCE:
      r.matches.clear()
   of PARAGRAPH:
      if not (r.par_prev == sentence.par_idx):
         r.matches.clear()
   else:
      discard

   for m in nre.find_iter($sentence.str, r.regex):
      var tmp: string
      if r.ignore_case:
         tmp = to_lower_ascii($m)
      else:
         tmp = $m

      if r.matches.has_key_or_put(tmp, 1):
         r.matches[tmp] += 1

      if (r.matches[tmp] > 1):
         let violation_pos = r.calculate_position(sentence.row_begin,
                                                  sentence.col_begin,
                                                  m.match_bounds.a + 1,
                                                  sentence.offset_pts)

         violations.add(r.create_violation(violation_pos, $m))

   # Remember the paragraph.
   r.par_prev = sentence.par_idx

   return violations


proc new*(t: typedesc[RuleConsistency], severity: Severity, message: string,
          source_file: string, display_name: string, regex_first: string,
          regex_second: string, scope: Scope,
          ignore_case: bool): RuleConsistency =
   var regex_flags = ""
   if ignore_case:
      regex_flags = "(?i)"

   return RuleConsistency(kind: "consistency",
                         severity: severity,
                         message: message,
                         source_file: source_file,
                         display_name: display_name,
                         ignore_case: ignore_case,
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
                                                  sentence.offset_pts)

         violations.add(r.create_violation(violation_pos, $m))

   # Analyze matches for the second regex.
   for m in nre.find_iter($sentence.str, r.regex_second):
      r.nof_matches_second += 1

      if (r.nof_matches_first > 0):
         let violation_pos = r.calculate_position(sentence.row_begin,
                                                  sentence.col_begin,
                                                  m.match_bounds.a + 1,
                                                  sentence.offset_pts)

         violations.add(r.create_violation(violation_pos, $m))

   # Remember the paragraph.
   r.par_prev = sentence.par_idx

   return violations

# Regexes should be auto-filled on an above level. Drafts are:
#   regex_def = r'(?:\b[A-Z][a-z]+ )+\(([A-Z]{3,5})\)'
#   regex_decl = r'\b([A-Z]{3,5})\b'
proc new*(t: typedesc[RuleDefinition], severity: Severity, message: string,
          source_file: string,  display_name: string, regex_def: string,
          regex_decl: string, exceptions: seq[string], scope: Scope,
          ignore_case: bool): RuleDefinition =
   var regex_flags = ""
   if ignore_case:
      regex_flags = "(?i)"

   return RuleDefinition(kind: "definition",
                         severity: severity,
                         message: message,
                         source_file: source_file,
                         display_name: display_name,
                         ignore_case: ignore_case,
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
                                        sentence.offset_pts)

         if r.definitions.has_key_or_put(def, pos):
            # TODO: Insert this warning message into a custom violation and
            #       add that to the sequence.
            log.warning("Redefinition of '$#' at $#:$#.",
                        def, $pos.row, $pos.col)

      except IndexError:
         # Abort if no capture group can be found. This should not happen due
         # to validation enforced at an earlier stage.
         log.abort(EnforceError,
                   "No capture group defined for declaration in file '$#'. " &
                   "This should not have occurred.", r.source_file)

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
                                 sentence.offset_pts)

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
         log.abort(EnforceError,
                   "No capture group defined for definition in file '$#'. " &
                   "This should not have occurred.", r.source_file)

   # Remember the paragraph.
   r.par_prev = sentence.par_idx

   return violations


proc new*(t: typedesc[RuleConditional], severity: Severity, message: string,
          source_file: string,  display_name: string, regex_first: string,
          regex_second: string, scope: Scope,
          ignore_case: bool): RuleConditional =
   var regex_flags = ""
   if ignore_case:
      regex_flags = "(?i)"

   return RuleConditional(kind: "conditional",
                          severity: severity,
                          message: message,
                          source_file: source_file,
                          display_name: display_name,
                          ignore_case: ignore_case,
                          regex_first: re(regex_flags & regex_first),
                          regex_second: re(regex_flags & regex_second),
                          scope: scope,
                          par_prev: 0,
                          first_observed: false)


method enforce*(r: RuleConditional, sentence: Sentence): seq[Violation] =
   var violations: seq[Violation] = @[]

   # Reset the match counter and alert status depending on the scope.
   case r.scope
   of SENTENCE:
      r.first_observed = false
   of PARAGRAPH:
      if not (r.par_prev == sentence.par_idx):
         r.first_observed = false
   else:
      discard

   var
      row_first = 0
      col_first = 0

   let m_first = nre.find($sentence.str, r.regex_first)
   if not is_none(m_first) and not r.first_observed:
      try:
         (row_first, col_first) =
            r.calculate_position(sentence.row_begin, sentence.col_begin,
                                 m_first.get.capture_bounds[0].get.a + 1,
                                 sentence.offset_pts)

         r.first_observed = true

      except IndexError:
         # Abort if no capture group can be found. This should not happen due
         # to validation enforced at an earlier stage.
         log.abort(EnforceError,
                   "No capture group defined for conditional in file '$#'. " &
                   "This should not have occurred.", r.source_file)

   for m_second in nre.find_iter($sentence.str, r.regex_second):
      let (row_second, col_second) =
         r.calculate_position(sentence.row_begin, sentence.col_begin,
                              m_second.match_bounds.a + 1, # TODO: Group here?
                              sentence.offset_pts)
      if (not r.first_observed or
          (row_first == row_second and col_first > col_second) or
          (row_first > row_second)):
         violations.add(r.create_violation((row_second, col_second), $m_second))

   # Remember the paragraph.
   r.par_prev = sentence.par_idx

   return violations
