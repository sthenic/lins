import nre
import strutils
import tables

import ./rules
import ../utils/log
import ../parsers/plain_parser


method enforce*(r: RuleOccurrence, seg: PlainTextSegment): seq[Violation] =
   # Reset the match counter and alert status depending on the scope.
   case r.scope
   of PARAGRAPH:
      if not (r.par_prev == seg.par_idx): # TODO: Check not strictly necessary any more.
         r.nof_matches = 0
         r.has_alerted = false
   else:
      discard

   # Call the base enforcement function
   result = enforce_base(r, seg)

   # Remember the paragraph.
   r.par_prev = seg.par_idx


method enforce*(r: RuleRepetition, seg: PlainTextSegment): seq[Violation] =
   case r.scope
   of PARAGRAPH:
      if not (r.par_prev == seg.par_idx):
         r.matches.clear()
   else:
      discard

   # Call the base enforcement function
   result = enforce_base(r, seg)

   # Remember the paragraph.
   r.par_prev = seg.par_idx


method enforce*(r: RuleConsistency, seg: PlainTextSegment): seq[Violation] =
   # Reset the match counter and alert status depending on the scope.
   case r.scope
   of PARAGRAPH:
      if not (r.par_prev == seg.par_idx):
         r.first_observed = false
   else:
      discard

   # Call the base enforcement function
   result = enforce_base(r, seg)

   # Remember the paragraph.
   r.par_prev = seg.par_idx


method enforce*(r: RuleDefinition, seg: PlainTextSegment): seq[Violation] =
   # Reset the match counter and alert status depending on the scope.
   case r.scope
   of PARAGRAPH:
      if not (r.par_prev == seg.par_idx):
         r.definitions.clear()
   else:
      discard

   # Call the base enforcement function
   result = enforce_base(r, seg)

   # Remember the paragraph.
   r.par_prev = seg.par_idx


method enforce*(r: RuleConditional, seg: PlainTextSegment): seq[Violation] =
   # Reset the match counter and alert status depending on the scope.
   case r.scope
   of PARAGRAPH:
      if not (r.par_prev == seg.par_idx):
         r.first_observed = false
   else:
      discard

   # Call the base enforcement function
   result = enforce_base(r, seg)

   # Remember the paragraph.
   r.par_prev = seg.par_idx
