import strutils
import strformat
import streams
import terminal
import nre
import sequtils
import unicode

import ../utils/log
import ../rules/rules
import ../parsers/base_parser


type
   LinterFileIOError* = object of Exception
   LinterValueError* = object of Exception
   LinterParseError* = object of Exception

   LinterDebugOptions* = tuple
      parser_output_filename: string

   ViolationCount = tuple
      error: int
      warning: int
      suggestion: int

   BaseLinter* = object of RootObj
      nof_violations_total*: ViolationCount
      nof_violations_file*: ViolationCount
      nof_files*: int
      minimal_mode*: bool
      severity_threshold*: Severity
      parser_output_stream*: Stream


proc open_linter*(l: var BaseLinter, minimal_mode: bool,
                  severity_threshold: Severity, parser_output_stream: Stream) =
   l.minimal_mode = minimal_mode
   l.severity_threshold = severity_threshold
   l.parser_output_stream = parser_output_stream


proc inc*(x: var ViolationCount, y: ViolationCount) =
   inc(x.error, y.error)
   inc(x.warning, y.warning)
   inc(x.suggestion, y.suggestion)


# Borrowed implementation from Nim/devel until these are released.
proc olen(s: string): int =
   var i = 0
   while i < s.len:
      inc(result)
      let L = graphemeLen(s, i)
      inc(i, L)


proc wrap_words*(s: string, maxLineWidth = 80,
                 splitLongWords = true,
                 seps: set[char] = Whitespace,
                 newLine = "\n"): string {.noSideEffect.} =
   result = newStringOfCap(s.len + s.len shr 6)
   var spaceLeft = maxLineWidth
   var lastSep = ""
   for word, isSep in tokenize(s, seps):
      let wlen = olen(word)
      if isSep:
         lastSep = word
         spaceLeft = spaceLeft - wlen
      elif wlen > spaceLeft:
         if splitLongWords and wlen > maxLineWidth:
            result.add(lastSep) # Bugfix
            var i = 0
            while i < word.len:
               if spaceLeft <= 0:
                  spaceLeft = maxLineWidth
                  result.add(newLine)
               dec(spaceLeft)
               let L = graphemeLen(word, i)
               for j in 0 ..< L:
                  result.add(word[i+j])
               inc(i, L)
         else:
            spaceLeft = maxLineWidth - wlen
            result.add(newLine)
            result.add(word)
      else:
         spaceLeft = spaceLeft - wlen
         result.add(lastSep)
         result.add(word)
         lastSep.setLen(0)


# Above implementation is not perfect. Improve the implementation below.
proc wrap_words_improve*(s: string, maxLineWidth = 80,
                         splitLongWords = true,
                         seps: set[char] = Whitespace,
                         newLine = "\n"): string {.noSideEffect.} =
   ## Word wraps `s`.
   result = newStringOfCap(s.len + s.len shr 6)
   var spaceLeft = maxLineWidth
   var lastSep = ""
   # TODO: We have to search the lastSep sequence for the last newline character
   #       to be able to correctly set how many characters are placed on the
   #       line.
   for word, isSep in tokenize(s, seps):
      if isSep:
         lastSep = word
         spaceLeft = spaceLeft - len(word)
         continue
      if len(word) > spaceLeft:
         if splitLongWords and len(word) > maxLineWidth:
            if contains(lastSep, NewLines):
               spaceLeft = maxLineWidth - len(lastSep)
            result.add(lastSep & substr(word, 0, spaceLeft-1))
            lastSep.setLen(0)
            var w = spaceLeft
            var wordLeft = len(word) - spaceLeft
            while wordLeft > 0:
               result.add(newLine)
               var L = min(maxLineWidth, wordLeft)
               spaceLeft = maxLineWidth - L
               result.add(substr(word, w, w+L-1))
               inc(w, L)
               dec(wordLeft, L)
         else:
            spaceLeft = maxLineWidth - len(word)
            result.add(newLine)
            result.add(word)
      else:
         if contains(lastSep, NewLines):
            spaceLeft = maxLineWidth - len(lastSep)
         spaceLeft = spaceLeft - len(word)
         result.add(lastSep & word)
         lastSep.setLen(0)


proc print_violation*(l: BaseLinter, v: Violation) =
   let message = wrap_words(v.message, 48, true).split_lines()

   var severity_color: ForegroundColor = fgWhite
   var severity_str: string = ""
   case v.severity
   of SUGGESTION:
      severity_str = "suggestion"
      severity_color = fgBlue
   of WARNING:
      severity_str = "warning"
      severity_color = fgYellow
   of ERROR:
      severity_str = "error"
      severity_color = fgRed
   else:
      log.abort(LinterValueError, "Unsupported severity level '$1'.",
                $v.severity)

   call_styled_write_line(&" l.{v.position.line:<4}  ",
                          styleBright, severity_color, &"{severity_str:<12}",
                          resetStyle, &"{message[0]:<48}    ",
                          styleBright, &"{v.display_name:<20}", resetStyle)

   for m in 1..<message.len:
      let tmp = ""
      call_styled_write_line(&"{tmp:21}{message[m]:<48}")


proc print_header*(l: BaseLinter, str: string) =
   # Suppress headers in minimal mode.
   if l.minimal_mode:
      return

   call_styled_write_line(styleBright, styleUnderscore, &"\n{str}", resetStyle)


proc print_footer*(l: BaseLinter, time_ms: float) =
   # Suppress footers in minimal mode.
   if l.minimal_mode:
      return

   call_styled_write_line(styleBright, "\n\nAnalysis completed in ", fgGreen,
                          format_float(time_ms, ffDecimal, 1), " ms",
                          resetStyle, styleBright, " with ", resetStyle)

   var file_str = ""
   if l.nof_files == 1:
      file_str = "in 1 file."
   elif l.nof_files > 1:
      file_str = &"in {l.nof_files} files."

   call_styled_write_line(
      styleBright, fgRed,
      &"  {l.nof_violations_total.error} errors", resetStyle, ", ",
      styleBright, fgYellow,
      &"{l.nof_violations_total.warning} warnings",  resetStyle, " and ",
      styleBright, fgBlue,
      &"{l.nof_violations_total.suggestion} suggestions", resetStyle,
      &" {file_str}"
   )
