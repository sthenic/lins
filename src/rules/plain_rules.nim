import tables

import ./rules
import ../parsers/plain_parser

export rules.reset, rules.enforce, rules.Rule, rules.Severity, rules.Violation


proc lint_filter(r: Rule, seg: PlainTextSegment): bool =
   result = (r.linter_kind == ANY) or (r.linter_kind == PLAIN)


proc enforce*(r: var Rule, seg: PlainTextSegment): seq[Violation] =
   if not lint_filter(r, seg):
      return

   case r.kind
   of Existence, Substitution:
      discard
   of Occurrence:
      # Reset the match counter and alert status depending on the scope.
      case r.plain_section.scope
      of PARAGRAPH:
         if not (r.par_prev == seg.par_idx): # TODO: Check not strictly necessary any more.
            r.nof_matches = 0
            r.has_alerted = false
      else:
         discard

   of Repetition:
      case r.plain_section.scope
      of PARAGRAPH:
         if not (r.par_prev == seg.par_idx):
            r.matches.clear()
      else:
         discard

   of Consistency:
      # Reset the match counter and alert status depending on the scope.
      case r.plain_section.scope
      of PARAGRAPH:
         if not (r.par_prev == seg.par_idx):
            r.first_observed = false
      else:
         discard

   of Definition:
      # Reset the match counter and alert status depending on the scope.
      case r.plain_section.scope
      of PARAGRAPH:
         if not (r.par_prev == seg.par_idx):
            r.definitions.clear()
      else:
         discard

   of Conditional:
      # Reset the match counter and alert status depending on the scope.
      case r.plain_section.scope
      of PARAGRAPH:
         if not (r.par_prev == seg.par_idx):
            r.first_observed = false
      else:
         discard

   result = enforce(r, seg.base)

   # Remember the paragraph.
   r.par_prev = seg.par_idx
