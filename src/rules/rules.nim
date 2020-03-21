import nre
import strutils
import tables

import ../utils/log
import ../parsers/base_parser
import ../parsers/plain_parser
import ../parsers/latex_parser

export ScopeKind

type
   EnforceError* = object of Exception
   EnforceNotImplementedError* = object of Exception

   Severity* = enum
      SUGGESTION
      WARNING
      ERROR

   ScopeLogic* = enum
      OR
      AND
      NOT

   LinterKind* = enum
      ANY
      PLAIN
      LATEX

   LaTeXScopeEntry* = tuple
      name: string # Maybe a regex?
      kind: ScopeKind
      before: string
      logic: ScopeLogic
      descend: bool

   PlainScopeEntry* = enum
      INVALID
      TEXT
      PARAGRAPH

   LaTeXRuleSection* = tuple
      scope: seq[LaTeXScopeEntry]

   PlainRuleSection* = tuple
      scope: PlainScopeEntry

   Limit* = enum
      MIN
      MAX

   Position = tuple
      line, col: int

   Violation* = tuple
      kind: string
      severity: Severity
      source_file: string
      message: string
      position: Position
      display_name: string

   RuleKind* = enum
      Existence,
      Substitution,
      Occurrence,
      Repetition,
      Consistency,
      Definition,
      Conditional

   Rule* = object
      severity*: Severity
      message*, source_file*, display_name*: string
      ignore_case*: bool
      latex_section*: LaTeXRuleSection
      plain_section*: PlainRuleSection
      linter_kind*: LinterKind
      regex_one*, regex_two*, exceptions*: Regex
      par_prev*: int
      case kind*: RuleKind
      of Existence:
         discard
      of Substitution:
         subst_table*: Table[string, string]
      of Occurrence:
         limit_val*: int
         limit_kind*: Limit
         nof_matches*: int
         has_alerted*: bool
      of Repetition:
         matches*: Table[string, int]
      of Consistency:
         first_observed*, second_observed*: bool
      of Definition:
         definitions*: Table[string, Position]
      of Conditional:
         observed*: bool


proc create_violation*(r: Rule, pos: Position,
                       message_args: varargs[string]): Violation =
   (kind: $r.kind, severity: r.severity, source_file: r.source_file,
    message: format(r.message, message_args), position: pos,
    display_name: r.display_name)


# Compute absolute file position of the rule violation using the absolute
# sentence position, the relative rule violation position within the
# sentence (one-dimensional) and the (original) newline positions within the
# sencence.
proc calculate_position*(r: Rule, line, col, violation_pos: int,
                         linebreaks: seq[Linebreak]): Position =
   if len(linebreaks) == 0:
      result = (line, violation_pos)
   else:
      var i = 0
      var p = 0
      var l = line

      while linebreaks[i].pos <= violation_pos:
         (p, l) = linebreaks[i]
         inc(i)
         if i == len(linebreaks):
            break

      result = (l, violation_pos - p)


proc `$`*(x: RuleKind): string =
   case x
   of Existence:
      return "existence"
   of Substitution:
      return "substitution"
   of Occurrence:
      return "occurrence"
   of Repetition:
      return "repetition"
   of Consistency:
      return "consistency"
   of Definition:
      return "definition"
   of Conditional:
      return "conditional"


proc new_rule(kind: RuleKind, severity: Severity,
              message, source_file, display_name: string,
              ignore_case: bool,
              plain_section: PlainRuleSection, latex_section: LaTeXRuleSection,
              linter_kind: LinterKind,
              regex_one, regex_two, regex_exceptions: string): Rule =
   result = Rule(kind: kind)
   result.severity = severity
   result.message = message
   result.source_file = source_file
   result.display_name = display_name
   result.ignore_case = ignore_case
   result.latex_section = latex_section
   result.plain_section = plain_section
   result.linter_kind = linter_kind
   result.regex_one = re(regex_one)
   result.regex_two = re(regex_two)
   result.exceptions = re(regex_exceptions)
   result.par_prev = 0


proc new_existence_rule*(severity: Severity,
                         message, source_file, display_name: string,
                         ignore_case: bool,
                         plain_section: PlainRuleSection,
                         latex_section: LaTeXRuleSection,
                         linter_kind: LinterKind,
                         regex, regex_exceptions: string): Rule =
   var regex_flags = ""
   if ignore_case:
      regex_flags = "(?i)"

   result = new_rule(Existence, severity, message, source_file, display_name,
                     ignore_case, plain_section, latex_section, linter_kind,
                     regex_flags & regex, "", regex_exceptions)


proc new_substitution_rule*(severity: Severity,
                            message, source_file, display_name: string,
                            ignore_case: bool,
                            plain_section: PlainRuleSection,
                            latex_section: LaTeXRuleSection,
                            linter_kind: LinterKind,
                            regex, regex_exceptions: string,
                            subst_table: Table[string, string]): Rule =
   var regex_flags = ""
   if ignore_case:
      regex_flags = "(?i)"

   var lsubst_table = init_table[string, string]()
   for key, value in pairs(subst_table):
      lsubst_table[regex_flags & key] = value

   result = new_rule(Substitution, severity, message, source_file, display_name,
                     ignore_case, plain_section, latex_section, linter_kind,
                     regex_flags & regex, "", regex_exceptions)
   result.subst_table = lsubst_table


proc new_occurrence_rule*(severity: Severity,
                          message, source_file, display_name: string,
                          ignore_case: bool,
                          plain_section: PlainRuleSection,
                          latex_section: LaTeXRuleSection,
                          linter_kind: LinterKind,
                          regex, regex_exceptions: string,
                          limit_val: int, limit_kind: Limit): Rule =
   var regex_flags = ""
   if ignore_case:
      regex_flags = "(?i)"

   result = new_rule(Occurrence, severity, message, source_file, display_name,
                     ignore_case, plain_section, latex_section, linter_kind,
                     regex_flags & regex, "", regex_exceptions)
   result.limit_val = limit_val
   result.limit_kind = limit_kind


proc new_repetition_rule*(severity: Severity,
                          message, source_file, display_name: string,
                          ignore_case: bool,
                          plain_section: PlainRuleSection,
                          latex_section: LaTeXRuleSection,
                          linter_kind: LinterKind,
                          regex, regex_exceptions: string): Rule =
   var regex_flags = ""
   if ignore_case:
      regex_flags = "(?i)"

   result = new_rule(Repetition, severity, message, source_file, display_name,
                     ignore_case, plain_section, latex_section, linter_kind,
                     regex_flags & regex, "", regex_exceptions)
   result.matches = init_table[string, int]()


proc new_consistency_rule*(severity: Severity,
                           message, source_file, display_name: string,
                           ignore_case: bool,
                           plain_section: PlainRuleSection,
                           latex_section: LaTeXRuleSection,
                           linter_kind: LinterKind,
                           regex_first, regex_second, regex_exceptions: string): Rule =
   var regex_flags = ""
   if ignore_case:
      regex_flags = "(?i)"

   result = new_rule(Consistency, severity, message, source_file, display_name,
                     ignore_case, plain_section, latex_section, linter_kind,
                     regex_flags & regex_first, regex_flags & regex_second,
                     regex_exceptions)

# Regexes should be auto-filled on an above level. Drafts are:
#   regex_def = r'(?:\b[A-Z][a-z]+ )+\(([A-Z]{3,5})\)'
#   regex_decl = r'\b([A-Z]{3,5})\b'
proc new_definition_rule*(severity: Severity,
                          message, source_file, display_name: string,
                          ignore_case: bool,
                          plain_section: PlainRuleSection, latex_section: LaTeXRuleSection,
                          linter_kind: LinterKind,
                          regex_def, regex_decl, regex_exceptions: string): Rule =
   var regex_flags = ""
   if ignore_case:
      regex_flags = "(?i)"

   result = new_rule(Definition, severity, message, source_file, display_name,
                     ignore_case, plain_section, latex_section, linter_kind,
                     regex_flags & regex_def, regex_flags & regex_decl,
                     regex_exceptions)
   result.definitions = init_table[string, Position]()


proc new_conditional_rule*(severity: Severity,
                           message, source_file, display_name: string,
                           ignore_case: bool,
                           plain_section: PlainRuleSection,
                           latex_section: LaTeXRuleSection,
                           linter_kind: LinterKind,
                           regex_first, regex_second, regex_exceptions: string): Rule =
   var regex_flags = ""
   if ignore_case:
      regex_flags = "(?i)"

   result = new_rule(Conditional, severity, message, source_file, display_name,
                     ignore_case, plain_section, latex_section, linter_kind,
                     regex_flags & regex_first, regex_flags & regex_second,
                     regex_exceptions)


proc reset*(r: var Rule) =
   r.par_prev = 0
   case r.kind
   of Existence, Substitution:
      discard
   of Occurrence:
      r.nof_matches = 0
      r.has_alerted = false
   of Repetition:
      r.matches = init_table[string, int]()
   of Consistency:
      r.first_observed = false
      r.second_observed = false
   of Definition:
      r.definitions = init_table[string, Position]()
   of Conditional:
      r.observed = false


proc reset*(s: var seq[Rule]) =
   for r in mitems(s):
      reset(r)


proc is_exception(str: string, regex: Regex): bool =
   result = len(regex.pattern) > 0 and contains(str, regex)


proc enforce_existence(r: Rule, seg: TextSegment): seq[Violation] =
   for m in nre.find_iter(seg.text, r.regex_one):
      if is_exception($m, r.exceptions):
         continue
      let violation_pos = r.calculate_position(seg.line, seg.col,
                                               m.match_bounds.a + 1,
                                               seg.linebreaks)
      result.add(r.create_violation(violation_pos, $m))


proc enforce_substitution(r: Rule, seg: TextSegment): seq[Violation] =
   for m in nre.find_iter(seg.text, r.regex_one):
      if is_exception($m, r.exceptions):
         continue
      let mpos = m.match_bounds.a
      let violation_pos = r.calculate_position(seg.line, seg.col, mpos + 1,
                                               seg.linebreaks)
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
      var subst = ""
      var m_str = $m
      if r.ignore_case:
         m_str = to_lower_ascii(m_str)
      for key, value in pairs(r.subst_table):
         var value_str = value
         if r.ignore_case:
            value_str = to_lower_ascii(value)
         if is_some(nre.match(seg.text, re(key), mpos)) and
               (m_str != value_str):
            subst = value
            break

      if subst != "":
         result.add(r.create_violation(violation_pos, $m, subst))


proc enforce_occurrence(r: var Rule, seg: TextSegment): seq[Violation] =
   for m in nre.find_iter(seg.text, r.regex_one):
      if is_exception($m, r.exceptions):
         continue
      # Count the match (pre-incrementation).
      r.nof_matches += 1

      # Check against the specified maximum limit. If the value is out of
      # bounds, we create a violation object, set the alert status and
      # break to avoid unnecessary loop iterations.
      if (not r.has_alerted and
          (r.limit_kind == MAX) and (r.nof_matches > r.limit_val)):
         let sentence_pos = (seg.line, seg.col)
         result.add(r.create_violation(sentence_pos))
         break
   # Check against the specified minimum limit. This is only supported in
   # the sentence scope. TODO: Remove since we don't have that any more?
   if (not r.has_alerted and
       (r.limit_kind == MIN) and (r.nof_matches < r.limit_val)):
      let sentence_pos = (seg.line, seg.col)
      result.add(r.create_violation(sentence_pos))


proc enforce_repetition(r: var Rule, seg: TextSegment): seq[Violation] =
   for m in nre.find_iter(seg.text, r.regex_one):
      if is_exception($m, r.exceptions):
         continue
      var tmp: string
      if r.ignore_case:
         tmp = to_lower_ascii($m)
      else:
         tmp = $m

      if r.matches.has_key_or_put(tmp, 1):
         r.matches[tmp] += 1

      if (r.matches[tmp] > 1):
         let violation_pos = r.calculate_position(seg.line, seg.col,
                                                  m.match_bounds.a + 1,
                                                  seg.linebreaks)

         result.add(r.create_violation(violation_pos, $m))


proc enforce_consistency(r: var Rule, seg: TextSegment): seq[Violation] =
   if not r.first_observed and not r.second_observed:
      # Analyze matches for the first and second regex.
      var regex_first_pos: seq[int]
      var regex_second_pos: seq[int]
      for m in nre.find_iter(seg.text, r.regex_one):
         add(regex_first_pos, m.match_bounds.a)
      for m in nre.find_iter(seg.text, r.regex_two):
         add(regex_second_pos, m.match_bounds.a)

      # Determine which one occurrs first.
      if len(regex_first_pos) > 0 and len(regex_second_pos) > 0:
         if regex_first_pos[0] == regex_second_pos[0]:
            log.abort(EnforceError,
               "Coinciding matches for conistency rule '$1' on line $2",
               r.display_name, $r.calculate_position(seg.line, seg.col,
                                                     regex_first_pos[0] + 1,
                                                     seg.linebreaks).line
            )
         elif regex_first_pos[0] < regex_second_pos[0]:
            r.first_observed = true
         else:
            r.second_observed = true
      elif len(regex_first_pos) == 0 and len(regex_second_pos) > 0:
         r.second_observed = true
      elif len(regex_first_pos) > 0 and len(regex_second_pos) == 0:
         r.first_observed = true

   # Go through the text segment again, generating violations for any
   # relevant matches.
   if r.first_observed:
      for m in nre.find_iter(seg.text, r.regex_two):
         let violation_pos = r.calculate_position(seg.line, seg.col,
                                                  m.match_bounds.a + 1,
                                                  seg.linebreaks)

         result.add(r.create_violation(violation_pos, $m))
   elif r.second_observed:
      for m in nre.find_iter(seg.text, r.regex_one):
         let violation_pos = r.calculate_position(seg.line, seg.col,
                                                  m.match_bounds.a + 1,
                                                  seg.linebreaks)

         result.add(r.create_violation(violation_pos, $m))


proc enforce_definition(r: var Rule, seg: TextSegment): seq[Violation] =
   # Go through the sentence looking for definitions. Store the position to
   # make sure we can differentiate the order of definitions and
   # declarations within a sentence.
   for m_def in nre.find_iter(seg.text, r.regex_one):
      try:
         let def = m_def.captures[0]
         let pos = r.calculate_position(seg.line, seg.col,
                                        m_def.capture_bounds[0].a + 1,
                                        seg.linebreaks)

         if r.definitions.has_key_or_put(def, pos):
            # TODO: Insert this warning message into a custom violation and
            #       add that to the sequence.
            log.warning("Redefinition of '$1' on line $2.", def, $pos.line)

      except IndexError:
         # Abort if no capture group can be found. This should not happen due
         # to validation enforced at an earlier stage.
         log.abort(EnforceError,
                   "No capture group defined for declaration in file '$1'. " &
                   "This should not have occurred.", r.source_file)

   # Run through the sentence looking for declarations. If the declaration
   # has no definition, the rule is violated outright. Otherwise, we have
   # to double-check the position of the declaration in relation to the
   # definition. We skip any declarations in the exception list.
   for m_decl in nre.find_iter(seg.text, r.regex_two):
      if is_exception($m_decl, r.exceptions):
         continue
      try:
         let decl = m_decl.captures[0]
         let (line_decl, col_decl) =
            r.calculate_position(seg.line, seg.col,
                                 m_decl.capture_bounds[0].a + 1,
                                 seg.linebreaks)

         var is_violated = false
         if not r.definitions.has_key(decl):
            is_violated = true
         else:
            let (line_def, col_def) = r.definitions[decl]

            if (line_def == line_decl and col_def > col_decl or
                line_def > line_decl):
               is_violated = true

         if is_violated:
            # TODO: Fix the Position type, maybe a raw tuple instead
            # let pos: Position = (line: line_decl, col: col_decl)
            result.add(r.create_violation((line_decl, col_decl), decl))


      except IndexError:
         # Abort if no capture group can be found. This should not happen due
         # to validation enforced at an earlier stage.
         log.abort(EnforceError,
                   "No capture group defined for definition in file '$1'. " &
                   "This should not have occurred.", r.source_file)


proc enforce_conditional(r: var Rule, seg: TextSegment): seq[Violation] =
   var line_first = 0
   var col_first = 0

   let m_first = nre.find(seg.text, r.regex_one)
   if not is_none(m_first) and not r.observed:
      try:
         (line_first, col_first) =
            r.calculate_position(seg.line, seg.col,
                                 m_first.get.capture_bounds[0].a + 1,
                                 seg.linebreaks)

         r.observed = true

      except IndexError:
         # Abort if no capture group can be found. This should not happen due
         # to validation enforced at an earlier stage.
         log.abort(EnforceError,
                   "No capture group defined for conditional in file '$1'. " &
                   "This should not have occurred.", r.source_file)

   for m_second in nre.find_iter(seg.text, r.regex_two):
      let (line_second, col_second) =
         r.calculate_position(seg.line, seg.col,
                              m_second.match_bounds.a + 1, # TODO: Group here?
                              seg.linebreaks)
      if (not r.observed or
          (line_first == line_second and col_first > col_second) or
          (line_first > line_second)):
         result.add(r.create_violation((line_second, col_second), $m_second))


proc enforce*(r: var Rule, seg: TextSegment): seq[Violation] =
   case r.kind
   of Existence:
      enforce_existence(r, seg)
   of Substitution:
      enforce_substitution(r, seg)
   of Occurrence:
      enforce_occurrence(r, seg)
   of Repetition:
      enforce_repetition(r, seg)
   of Consistency:
      enforce_consistency(r, seg)
   of Definition:
      enforce_definition(r, seg)
   of Conditional:
      enforce_conditional(r, seg)
