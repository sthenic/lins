import nre
import strutils
import tables

import ./rules
import ../utils/log
import ../parsers/plain_parser

export rules.reset, rules.enforce, rules.Rule, rules.Severity, rules.Violation


proc lint_filter(r: Rule, seg: PlainTextSegment): bool =
   result = (r.linter_kind == ANY) or (r.linter_kind == PLAIN)


method enforce*(r: RuleExistence, seg: PlainTextSegment): seq[Violation] =
   if not lint_filter(r, seg):
      return

   result = proc_call(enforce(r, TextSegment(seg)))


method enforce*(r: RuleSubstitution, seg: PlainTextSegment): seq[Violation] =
   if not lint_filter(r, seg):
      return

   result = proc_call(enforce(r, TextSegment(seg)))


method enforce*(r: RuleOccurrence, seg: PlainTextSegment): seq[Violation] =
   if not lint_filter(r, seg):
      return

   # Reset the match counter and alert status depending on the scope.
   case r.plain_section.scope
   of PARAGRAPH:
      if not (r.par_prev == seg.par_idx): # TODO: Check not strictly necessary any more.
         r.nof_matches = 0
         r.has_alerted = false
   else:
      discard

   result = proc_call(enforce(r, TextSegment(seg)))

   # Remember the paragraph.
   r.par_prev = seg.par_idx


method enforce*(r: RuleRepetition, seg: PlainTextSegment): seq[Violation] =
   if not lint_filter(r, seg):
      return

   case r.plain_section.scope
   of PARAGRAPH:
      if not (r.par_prev == seg.par_idx):
         r.matches.clear()
   else:
      discard

   result = proc_call(enforce(r, TextSegment(seg)))

   # Remember the paragraph.
   r.par_prev = seg.par_idx


method enforce*(r: RuleConsistency, seg: PlainTextSegment): seq[Violation] =
   if not lint_filter(r, seg):
      return

   # Reset the match counter and alert status depending on the scope.
   case r.plain_section.scope
   of PARAGRAPH:
      if not (r.par_prev == seg.par_idx):
         r.first_observed = false
   else:
      discard

   result = proc_call(enforce(r, TextSegment(seg)))

   # Remember the paragraph.
   r.par_prev = seg.par_idx


method enforce*(r: RuleDefinition, seg: PlainTextSegment): seq[Violation] =
   if not lint_filter(r, seg):
      return

   # Reset the match counter and alert status depending on the scope.
   case r.plain_section.scope
   of PARAGRAPH:
      if not (r.par_prev == seg.par_idx):
         r.definitions.clear()
   else:
      discard

   result = proc_call(enforce(r, TextSegment(seg)))

   # Remember the paragraph.
   r.par_prev = seg.par_idx


method enforce*(r: RuleConditional, seg: PlainTextSegment): seq[Violation] =
   if not lint_filter(r, seg):
      return

   # Reset the match counter and alert status depending on the scope.
   case r.plain_section.scope
   of PARAGRAPH:
      if not (r.par_prev == seg.par_idx):
         r.first_observed = false
   else:
      discard

   result = proc_call(enforce(r, TextSegment(seg)))

   # Remember the paragraph.
   r.par_prev = seg.par_idx
