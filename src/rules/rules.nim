import nre
import unicode
import strutils
import tables

import ../utils/log
import ../parsers/base_parser

type
   EnforceError* = object of Exception
   EnforceNotImplementedError* = object of Exception

   Severity* = enum
      ERROR
      WARNING
      SUGGESTION

   Scope* = enum
      TEXT
      PARAGRAPH

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

   Rule* = ref object of RootObj
      kind*: string
      severity*: Severity
      message*: string
      source_file*: string
      display_name*: string
      ignore_case*: bool

   RuleExistence* = ref object of Rule
      regex*: Regex

   RuleSubstitution* = ref object of Rule
      regex*: Regex
      subst_table*: Table[string, string]

   RuleOccurrence* = ref object of Rule
      regex*: Regex
      limit_val*: int
      limit_kind*: Limit
      scope*: Scope
      nof_matches*: int
      par_prev*: int
      has_alerted*: bool

   RuleRepetition* = ref object of Rule
      regex*: Regex
      scope*: Scope
      par_prev*: int
      matches*: Table[string, int]

   RuleConsistency* = ref object of Rule
      regex_first*: Regex
      regex_second*: Regex
      scope*: Scope
      par_prev*: int
      first_observed*: bool
      second_observed*: bool

   RuleDefinition* = ref object of Rule
      regex_def*: Regex
      regex_decl*: Regex
      exceptions*: seq[string]
      scope*: Scope
      definitions*: Table[string, Position]
      par_prev*: int

   RuleConditional* = ref object of Rule
      regex_first*: Regex
      regex_second*: Regex
      scope*: Scope
      par_prev*: int
      first_observed*: bool


proc create_violation*(r: Rule, pos: Position,
                      message_args: varargs[string]): Violation =
   (kind: r.kind, severity: r.severity, source_file: r.source_file,
    message: format(r.message, message_args), position: pos,
    display_name: r.display_name)


# Compute absolute file position of the rule violation using the absolute
# sentence position, the relative rule violation position within the
# sentence (one-dimensional) and the (original) newline positions within the
# sencence.
proc calculate_position*(r: Rule, line, col, violation_pos: int,
                         linebreaks: seq[Linebreak]): Position =
   if len(linebreaks) == 0:
      result = (line, 0)
   else:
      var i = 0
      var l = line

      while linebreaks[i].pos <= violation_pos:
         l = linebreaks[i].line
         i += 1
         if i == len(linebreaks):
            break

      result = (l, 0)


# Constructors
proc new*(t: typedesc[Rule], kind: string, severity: Severity, message: string,
          source_file: string, display_name: string): Rule =
   Rule(kind: kind, severity: severity, message: message,
        source_file: source_file, display_name: display_name)


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
                         scope: scope)


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
                         matches: init_table[string, int]())


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
                         scope: scope)


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
                         definitions: init_table[string, Position]())


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
                          scope: scope)


method reset*(r: Rule) {.base.} =
   discard


method reset*(r: RuleOccurrence) =
   r.nof_matches = 0
   r.has_alerted = false


method reset*(r: RuleRepetition) =
   r.par_prev = 0
   r.matches = init_table[string, int]()


method reset*(r: RuleConsistency) =
   r.par_prev = 0
   r.first_observed = false
   r.second_observed = false


method reset*(r: RuleDefinition) =
   r.par_prev = 0
   r.definitions = init_table[string, Position]()


method reset*(r: RuleConditional) =
   r.par_prev = 0
   r.first_observed = false


proc reset*(s: seq[Rule]) =
   for r in s: reset(r)


# Base implementations of enforcement methods. Input segment type is the base
# 'TextSegment' as defined by the base parser module.
method enforce*(r: Rule, seg: TextSegment): seq[Violation] {.base.} =
   log.abort(EnforceNotImplementedError,
             "Rule enforcement not implemented for rule '$1'.", r.kind)


method enforce*(r: RuleExistence, seg: TextSegment): seq[Violation] =
   for m in nre.find_iter(seg.text, r.regex):
      let violation_pos = r.calculate_position(seg.line, seg.col,
                                               m.match_bounds.a + 1,
                                               seg.linebreaks)

      result.add(r.create_violation(violation_pos, $m))


method enforce*(r: RuleSubstitution, seg: TextSegment): seq[Violation] =
   for m in nre.find_iter(seg.text, r.regex):
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
      var
         subst = ""
         m_str = $m
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


method enforce*(r: RuleOccurrence, seg: TextSegment): seq[Violation] =
   for m in nre.find_iter(seg.text, r.regex):
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
   # the sentence scope.
   if (not r.has_alerted and
       (r.limit_kind == MIN) and (r.nof_matches < r.limit_val)):
      let sentence_pos = (seg.line, seg.col)
      result.add(r.create_violation(sentence_pos))


method enforce*(r: RuleRepetition, seg: TextSegment): seq[Violation] =
   for m in nre.find_iter(seg.text, r.regex):
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


method enforce*(r: RuleConsistency, seg: TextSegment): seq[Violation] =
   if not r.first_observed and not r.second_observed:
      # Analyze matches for the first and second regex.
      var regex_first_pos: seq[int]
      var regex_second_pos: seq[int]
      for m in nre.find_iter(seg.text, r.regex_first):
         add(regex_first_pos, m.match_bounds.a)
      for m in nre.find_iter(seg.text, r.regex_second):
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
      for m in nre.find_iter(seg.text, r.regex_second):
         let violation_pos = r.calculate_position(seg.line, seg.col,
                                                  m.match_bounds.a + 1,
                                                  seg.linebreaks)

         result.add(r.create_violation(violation_pos, $m))
   elif r.second_observed:
      for m in nre.find_iter(seg.text, r.regex_first):
         let violation_pos = r.calculate_position(seg.line, seg.col,
                                                  m.match_bounds.a + 1,
                                                  seg.linebreaks)

         result.add(r.create_violation(violation_pos, $m))


method enforce*(r: RuleDefinition, seg: TextSegment): seq[Violation] =
   # Go through the sentence looking for definitions. Store the position to
   # make sure we can differentiate the order of definitions and
   # declarations within a sentence.
   for m_def in nre.find_iter(seg.text, r.regex_def):
      try:
         let def = m_def.captures[0]
         let pos = r.calculate_position(seg.line, seg.col,
                                        m_def.capture_bounds[0].get.a + 1,
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
   for m_decl in nre.find_iter(seg.text, r.regex_decl):
      try:
         let decl = m_decl.captures[0]
         if decl in r.exceptions:
            continue

         let (line_decl, col_decl) =
            r.calculate_position(seg.line, seg.col,
                                 m_decl.capture_bounds[0].get.a + 1,
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


method enforce*(r: RuleConditional, seg: TextSegment): seq[Violation] =
   var line_first = 0
   var col_first = 0

   let m_first = nre.find(seg.text, r.regex_first)
   if not is_none(m_first) and not r.first_observed:
      try:
         (line_first, col_first) =
            r.calculate_position(seg.line, seg.col,
                                 m_first.get.capture_bounds[0].get.a + 1,
                                 seg.linebreaks)

         r.first_observed = true

      except IndexError:
         # Abort if no capture group can be found. This should not happen due
         # to validation enforced at an earlier stage.
         log.abort(EnforceError,
                   "No capture group defined for conditional in file '$1'. " &
                   "This should not have occurred.", r.source_file)

   for m_second in nre.find_iter(seg.text, r.regex_second):
      let (line_second, col_second) =
         r.calculate_position(seg.line, seg.col,
                              m_second.match_bounds.a + 1, # TODO: Group here?
                              seg.linebreaks)
      if (not r.first_observed or
          (line_first == line_second and col_first > col_second) or
          (line_first > line_second)):
         result.add(r.create_violation((line_second, col_second), $m_second))
