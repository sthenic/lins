import nre
import strutils
import tables

import ./rules
import ../utils/log
import ../parsers/latex_parser

export rules.reset, rules.enforce, rules.Rule, rules.Severity, rules.Violation


proc scope_filter(r: Rule, seg: LaTeXTextSegment): bool =
   for scope_entry in seg.scope:
      if scope_entry.kind == ScopeKind.Comment:
         return false
   if len(r.latex.scope) == 0:
      return true

   var entry_match: seq[tuple[match: bool, logic: ScopeLogic]]
   for rule_entry in r.latex.scope:
      # Determine if the context is matches any user defined expressions.
      var context_match = true
      if len(rule_entry.before) > 0:
         context_match = is_some(nre.find(seg.context.before,
                                          re(rule_entry.before)))
      if len(rule_entry.after) > 0:
         context_match = context_match and
                           is_some(nre.find(seg.context.after,
                                          re(rule_entry.after)))

      # Determine if the rule entry matches any scope entry of the current
      # segment.
      var matched = false
      for scope_entry in seg.scope:
         if rule_entry.name == scope_entry.name:
            # TODO: Let rule_entry.kind have the same type as scope_entry.kind
            #       so we can do the check right away.
            matched = (rule_entry.kind == "environment" and
                       scope_entry.kind == ScopeKind.Environment) or
                      (rule_entry.kind == "control sequence" and
                       scope_entry.kind == ScopeKind.ControlSequence) or
                      (rule_entry.kind == "math" and
                       scope_entry.kind == ScopeKind.Math)
         if matched:
            add(entry_match, (context_match, rule_entry.logic))
            break

      if not matched:
         add(entry_match, (false, rule_entry.logic))

   # Calculate if the rule should be enforced or not.
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

   result = (enforce_or or enforce_and) and not enforce_not


method enforce*(r: RuleExistence, seg: LaTeXTextSegment): seq[Violation] =
   if not seg.do_lint or not scope_filter(r, seg):
      return

   # Call the base enforcement function
   result = proc_call(enforce(r, TextSegment(seg)))


method enforce*(r: RuleSubstitution, seg: LaTeXTextSegment): seq[Violation] =
   if not seg.do_lint or not scope_filter(r, seg):
      return

   # Call the base enforcement function
   result = proc_call(enforce(r, TextSegment(seg)))


method enforce*(r: RuleOccurrence, seg: LaTeXTextSegment): seq[Violation] =
   if not seg.do_lint or not scope_filter(r, seg):
      return

   # Call the base enforcement function
   result = proc_call(enforce(r, TextSegment(seg)))


method enforce*(r: RuleRepetition, seg: LaTeXTextSegment): seq[Violation] =
   if not seg.do_lint or not scope_filter(r, seg):
      return

   # Call the base enforcement function
   result = proc_call(enforce(r, TextSegment(seg)))


method enforce*(r: RuleConsistency, seg: LaTeXTextSegment): seq[Violation] =
   if not seg.do_lint or not scope_filter(r, seg):
      return

   # Call the base enforcement function
   result = proc_call(enforce(r, TextSegment(seg)))


method enforce*(r: RuleDefinition, seg: LaTeXTextSegment): seq[Violation] =
   if not seg.do_lint or not scope_filter(r, seg):
      return

   # Call the base enforcement function
   result = proc_call(enforce(r, TextSegment(seg)))


method enforce*(r: RuleConditional, seg: LaTeXTextSegment): seq[Violation] =
   if not seg.do_lint or not scope_filter(r, seg):
      return

   # Call the base enforcement function
   result = proc_call(enforce(r, TextSegment(seg)))
