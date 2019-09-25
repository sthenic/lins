import nre

import ./rules
import ../parsers/latex_parser

export rules.reset, rules.enforce, rules.Rule, rules.Severity, rules.Violation


proc is_only_not(r: Rule): bool =
   ## Returns ``true`` if the rule only defines scope entries with the 'NOT'
   ## logic.
   result = true
   for rule_entry in r.latex_section.scope:
      if rule_entry.logic != NOT:
         return false


proc is_comment(seg: LaTeXTextSegment): bool =
   for scope_entry in seg.scope:
      if scope_entry.kind == ScopeKind.Comment:
         return true


proc scope_filter(r: Rule, seg: LaTeXTextSegment): bool =
   let is_comment = is_comment(seg)
   if len(r.latex_section.scope) == 0:
      # If a rule has no scope defined we return true except for segments with
      # the comment scope. You have to explicity state in the rule file that
      # the comment scope should be accepted.
      return not is_comment

   var entry_match: seq[tuple[match: bool, logic: ScopeLogic]]
   for rule_entry in r.latex_section.scope:
      # Determine if the rule entry matches any scope entry of the current
      # segment.
      var matched = false
      for i, scope_entry in seg.scope:
         if rule_entry.name == scope_entry.name and
            rule_entry.kind == scope_entry.kind:
            # Check to see if the rule scope entry should descend, i.e. if the
            # matching scope entry is _not_ the last element, and descending is
            # not allowed, we continue. This allows nesting of scopes which
            # shouldn't descend.
            if not rule_entry.descend and i < high(seg.scope):
               continue

            # Determine if the context is matches any user defined expressions.
            var context_match = true
            if len(rule_entry.before) > 0:
               context_match = is_some(nre.find(scope_entry.context.before,
                                                re(rule_entry.before)))
            # TODO: Check for trailing context match once that's fully
            #       implemented.
            add(entry_match, (context_match, rule_entry.logic))
            matched = true
            break

      if not matched:
         add(entry_match, (false, rule_entry.logic))

   # Calculate whether the rule should be enforced or not.
   var enforce_and = false
   var enforce_or = false
   var enforce_not = false
   var first_and = true
   for match, logic in items(entry_match):
      case logic:
      of OR:
         enforce_or = enforce_or or match
      of AND:
         enforce_and = (enforce_and or first_and) and match
         first_and = false
      of NOT:
         enforce_not = enforce_not or match

   result = (enforce_or or enforce_and or
             (is_only_not(r) and not is_comment)) and not enforce_not


proc lint_filter(r: Rule, seg: LaTeXTextSegment): bool =
   ## Returns true if the seg should be linted with the rule object r.
   result = seg.do_lint and scope_filter(r, seg) and
            (r.linter_kind == ANY or r.linter_kind == LATEX)


method enforce*(r: RuleExistence, seg: LaTeXTextSegment): seq[Violation] =
   if not lint_filter(r, seg):
      return

   result = proc_call(enforce(r, TextSegment(seg)))


method enforce*(r: RuleSubstitution, seg: LaTeXTextSegment): seq[Violation] =
   if not lint_filter(r, seg):
      return

   result = proc_call(enforce(r, TextSegment(seg)))


method enforce*(r: RuleOccurrence, seg: LaTeXTextSegment): seq[Violation] =
   if not lint_filter(r, seg):
      return

   result = proc_call(enforce(r, TextSegment(seg)))


method enforce*(r: RuleRepetition, seg: LaTeXTextSegment): seq[Violation] =
   if not lint_filter(r, seg):
      return

   result = proc_call(enforce(r, TextSegment(seg)))


method enforce*(r: RuleConsistency, seg: LaTeXTextSegment): seq[Violation] =
   if not lint_filter(r, seg):
      return

   result = proc_call(enforce(r, TextSegment(seg)))


method enforce*(r: RuleDefinition, seg: LaTeXTextSegment): seq[Violation] =
   if not lint_filter(r, seg):
      return

   result = proc_call(enforce(r, TextSegment(seg)))


method enforce*(r: RuleConditional, seg: LaTeXTextSegment): seq[Violation] =
   if not lint_filter(r, seg):
      return

   result = proc_call(enforce(r, TextSegment(seg)))
