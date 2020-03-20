import streams
import strutils

import ../lexers/tex_lexer
import ../utils/log
import ./base_parser

export ParseError, TextSegment

type
   Enclosure* {.pure.} = enum
      Invalid
      Option
      Group
      Environment
      Math
      DisplayMath

   ScopeKind* {.pure.} = enum
      Invalid
      ControlSequence
      Environment
      Math
      Comment

   ScopeEntry* = object
      name*: string
      kind*: ScopeKind
      encl*: Enclosure
      count*: int
      delimiter_count*: int
      context*: Context

   LaTeXParser* = object
      lex: TeXLexer
      tok: TeXToken
      segs: seq[LaTeXTextSegment] # Completed segments
      seg: LaTeXTextSegment # Segment under construction
      seg_stack: seq[LaTeXTextSegment] # Incomplete segments
      scope: seq[ScopeEntry] # Complete scope
      scope_entry: ScopeEntry # Scope entry under construction
      last_tok: TeXToken
      last_tok_stack: seq[TeXToken]
      delimiter_count: int # Delimiter count
      is_enabled: bool

   LaTeXTextSegment* = object
      scope*: seq[ScopeEntry]
      base*: TextSegment
      expand: bool
      do_lint*: bool # TODO: Think of a better name? Maybe 'valid'?


const NOF_CONTEXT_CHARS = 15
const ESCAPED_CHARACTERS: set[char] = {'%', '&', '_', '#', '$', '~'}
const EXPANDED_CONTROL_WORDS: seq[string] = @[
   "textrm",
   "textsf",
   "textnormal",
   "textbf",
   "textmd",
   "textit",
   "textsl",
   "textsc",
   "textup",
   "emph"
]
const EXPANDED_ENVIRONMENTS: seq[string] = @[]
const MATH_ENVIRONMENTS: seq[string] = @["equation", "equation*"]

# Forward declarations
proc parse_character(p: var LaTeXParser)
proc parse_token(p: var LaTeXParser)


proc attach_line(tok: TeXToken, str: string): string =
   result = "(l." & $tok.line & ") " & str


proc is_empty[T](s: seq[T]): bool =
   return s == @[]


proc is_empty(s: ScopeEntry): bool =
   return s.kind == ScopeKind.Invalid


proc is_in_enclosure(p: LaTeXParser, encl: Enclosure): bool =
   return not is_empty(p.scope) and p.scope[^1].encl == encl


proc is_in_math_scope(seg: LaTeXTextSegment): bool =
   ## Checks if ``seg`` is in any math scope.
   # This includes the pure TeX modes denoted by ScopeKind.Math and any
   # environment in MATH_ENVIRONMENTS.
   for entry in seg.scope:
      if (entry.kind == ScopeKind.Math) or
         (entry.kind == ScopeKind.Environment and
          entry.encl == Enclosure.Environment and
          entry.name in MATH_ENVIRONMENTS):
         return true


proc is_matching_delimiter(p: LaTeXParser): bool =
   return not is_empty(p.scope) and
          p.scope[^1].delimiter_count == p.delimiter_count


proc get_token*(p: var LaTeXParser) =
   ## Get the next token from the lexer and store it in the `tok` member.
   get_token(p.lex, p.tok)


proc init(s: var LaTeXTextSegment) =
   set_len(s.scope, 0)
   s.expand = false
   s.do_lint = true
   init(s.base)


proc init(s: var ScopeEntry) =
   set_len(s.name, 0)
   s.encl = Enclosure.Invalid
   s.kind = ScopeKind.Invalid
   set_len(s.context.before, 0)
   set_len(s.context.after, 0)
   s.count = 0
   s.delimiter_count = 0


proc open_parser*(p: var LaTeXParser, filename: string, s: Stream) =
   init(p.tok)
   init(p.seg)
   init(p.last_tok)
   init(p.scope_entry)
   set_len(p.segs, 0)
   set_len(p.seg_stack, 0)
   set_len(p.scope, 0)
   set_len(p.last_tok_stack, 0)
   p.delimiter_count = 0
   p.is_enabled = true
   open_lexer(p.lex, filename, NOF_CONTEXT_CHARS, s)


proc close_parser*(p: var LaTeXParser) =
   close_lexer(p.lex)


proc add_tok(p: var LaTeXParser) =
   if len(p.seg.base.text) == 0:
      p.seg.base.line = p.tok.line
      p.seg.base.col = p.tok.col
   elif is_valid(p.last_tok) and p.tok.line > p.last_tok.line:
      add(p.seg.base.linebreaks, (len(p.seg.base.text), p.tok.line))

   add(p.seg.base.text, p.tok.token)
   p.last_tok = p.tok


proc add_seg(p: var LaTeXParser, seg: var LaTeXTextSegment) =
   ## Add a segment to the sequence of completed segments.
   seg.do_lint = p.is_enabled
   if len(seg.base.text.strip()) != 0:
      # We skip adding segments with length zero or consisting entirely of
      # whitespace.
      add(p.segs, seg)


proc begin_enclosure(p: var LaTeXParser, keep_scope, expand: bool,
                     context_before: string) =
   # Push the current text segment to the stack.
   add(p.seg_stack, p.seg)
   add(p.last_tok_stack, p.last_tok)
   # Push the current scope entry to the scope.
   p.scope_entry.context.before = context_before
   add(p.scope, p.scope_entry)
   # Reinitialize the text segment w/ the current scope.
   init(p.seg)
   p.seg.scope = p.scope
   p.seg.expand = expand
   # Reinitialize the last token.
   init(p.last_tok)
   # Reinitialize the scope entry unless we're told to keep it. This only
   # happens when an environment is entered since there may be options and
   # capture groups following the \begin{env} statement.
   if not keep_scope:
      init(p.scope_entry)


proc is_on_different_lines(x, y: LaTeXTextSegment): bool =
   ## Check if the segment ``y`` starts on a different line from wherever ``x``
   ## has reached.
   if len(x.base.linebreaks) != 0:
      result = y.base.line > x.base.linebreaks[^1].line
   else:
      result = y.base.line > x.base.line


proc expand_segment(p: var LaTeXParser, inner: LaTeXTextSegment) =
   # The inner segment should be 'expanded' and thus added to the outer text
   # segment. All the linebreaks of the inner segment gets added to the
   # outer with modified positions (their coordinates are absolute). If the
   # outer segment has length zero, we also pass on the segment starting
   # position. Otherwise, we have to check if the inner segment starts at a
   # different line from the last recorded line in the outer segment. In that
   # case, we add a linebreak pointing at the first character of the inner
   # segment.
   let outer_len = len(p.seg.base.text)
   if outer_len == 0:
      p.seg.base.line = inner.base.line
      p.seg.base.col = inner.base.col
   elif is_on_different_lines(p.seg, inner):
      add(p.seg.base.linebreaks, (outer_len, inner.base.line))

   for lb in inner.base.linebreaks:
      add(p.seg.base.linebreaks, (outer_len + lb.pos, lb.line))
   add(p.seg.base.text, inner.base.text)


proc end_enclosure(p: var LaTeXParser, context_after: string) =
   var inner = p.seg
   p.seg = pop(p.seg_stack)
   if inner.expand:
      # Pop the text segment stack and expand the inner segment into the outer
      # segment. The last token should remain.
      expand_segment(p, inner)
      discard pop(p.last_tok_stack)
   else:
      # Otherwise, the segment is not to be expanded so we just add the segment
      # to the list of completed segments. We restore last_tok from the stack.
      add_seg(p, inner)
      p.last_tok = pop(p.last_tok_stack)
   # Restore the scope entry.
   p.scope_entry = pop(p.scope)


proc handle_par(p: var LaTeXParser) =
   # The current text segment should end here and be added to the list of
   # completed text segments. However, if this segment should be expanded we
   # add the partial result to the outer segment and push the outer segment
   # back onto the stack.
   var inner = p.seg
   if inner.expand and len(p.seg_stack) != 0:
      p.seg = pop(p.seg_stack)
      expand_segment(p, inner)
      # Push the outer segment back onto the stack.
      add(p.seg_stack, p.seg)
   else:
      add_seg(p, inner)

   # Initialize a new text segment with identical scope to the one we just added
   # to the list of completed segments.
   p.seg = LaTeXTextSegment(scope: inner.scope, expand: inner.expand)


proc handle_category_1(p: var LaTeXParser) =
   # Beginning of group character. If the current scope entry is empty, this
   # group does not belong to any object and we continue with just incrementing
   # the delimiter count. However, if the scope entry is not empty, we update
   # the entry and begin another enclosure since this is a group that belongs
   # to a control word.
   inc(p.delimiter_count)
   if not is_empty(p.scope_entry):
      p.scope_entry = ScopeEntry(name: p.scope_entry.name,
                                 kind: p.scope_entry.kind,
                                 encl: Group,
                                 count: p.scope_entry.count + 1,
                                 delimiter_count: p.delimiter_count)
      begin_enclosure(p, false, false, p.tok.context.before)
   get_token(p)


proc handle_category_2(p: var LaTeXParser) =
   # Handle end of group characters. If we're in a group enclosure and the
   # delimiter count is equal to that of the closest scope entry, we end the
   # current enclosure. The delimiter count is always decremented.
   if is_in_enclosure(p, Group) and is_matching_delimiter(p):
      end_enclosure(p, p.tok.context.after)
   dec(p.delimiter_count)
   get_token(p)


proc handle_category_3(p: var LaTeXParser) =
   # Handle math shift characters.
   if is_in_enclosure(p, Enclosure.DisplayMath):
      # Ends with the next character.
      get_token(p)
      if p.tok.catcode != 3:
         # Error condition.
         log.abort(ParseError, attach_line(p.tok, "Display math section " &
                   "ended without two characters of catcode 3, e.g. '$$'."))
      end_enclosure(p, p.tok.context.after)
      get_token(p)
   elif is_in_enclosure(p, Enclosure.Math):
      # Ends with this character.
      end_enclosure(p, p.tok.context.after)
      get_token(p)
   else:
      # Enclosure begins, peek the next character to determine the type
      # of math enclosure. For display math, TeX requires that the '$$'
      # delimiter occurs next to each other.
      var context_before = p.tok.context.before
      get_token(p)
      if p.tok.catcode == 3:
         p.scope_entry = ScopeEntry(kind: ScopeKind.Math,
                                    encl: Enclosure.DisplayMath)
         begin_enclosure(p, false, false, context_before)
         get_token(p)
      else:
         p.scope_entry = ScopeEntry(kind: ScopeKind.Math,
                                    encl: Enclosure.Math)
         begin_enclosure(p, false, false, context_before)
         # Recursively parse the token.
         parse_token(p)


proc handle_category_12(p: var LaTeXParser) =
   # Handle 'other' characters.
   if p.tok.token == "[" and not is_empty(p.scope_entry) and
      not is_in_math_scope(p.seg):
      p.scope_entry = ScopeEntry(name: p.scope_entry.name,
                                 kind: p.scope_entry.kind,
                                 encl: Option,
                                 count: p.scope_entry.count + 1)
      begin_enclosure(p, false, false, p.tok.context.before)
   elif p.tok.token == "]" and is_in_enclosure(p, Option):
      end_enclosure(p, p.tok.context.after)
   else:
      add_tok(p)
   get_token(p)


proc parse_character(p: var LaTeXParser) =
   # TODO: Maybe detect unbalanced grouping characters.
   case p.tok.catcode
   of 1:
      handle_category_1(p)
   of 2:
      handle_category_2(p)
   of 3:
      handle_category_3(p)
   of 12:
      handle_category_12(p)
   else:
      init(p.scope_entry)
      add_tok(p)
      get_token(p)


proc get_group_as_string(p: var LaTeXParser): string =
   ## Read and return the next group as a string. The parser is set up to point
   ## at the next token to parse when this function returns.
   get_token(p)
   if p.tok.catcode == 1:
      # Begin group character, search until a matching end group character.
      var count = 1
      while true:
         get_token(p)
         if p.tok.catcode == 1:
            inc(count)
         elif p.tok.catcode == 2:
            dec(count)
         elif p.tok.token_type == EndOfFile:
            log.abort(ParseError, attach_line(p.tok, "Unexpected end of " &
                      "file when parsing capture group."))
         else:
            add(result, p.tok.token)
         if count == 0:
            break
   else:
      add(result, p.tok.token)


proc parse_control_word(p: var LaTeXParser) =
   var context_before = p.tok.context.before
   case p.tok.token
   of "begin":
      let env = get_group_as_string(p) # Stops at '}'
      p.scope_entry = ScopeEntry(name: env, kind: ScopeKind.Environment,
                                 encl: Enclosure.Environment)
      begin_enclosure(p, true, contains(EXPANDED_ENVIRONMENTS, env),
                      context_before)
      get_token(p)
   of "end":
      let env = get_group_as_string(p) # Stops at '}'
      if is_in_enclosure(p, Enclosure.Environment):
         end_enclosure(p, p.tok.context.after)
         if p.scope_entry.name != env:
            log.abort(ParseError, attach_line(p.tok, "Environment name " &
                      "mismatch '" & env & "' closes '" & p.scope_entry.name &
                      "'."))
         init(p.scope_entry)
         get_token(p) # Scan over '}'
      else:
         log.abort(ParseError, attach_line(p.tok, "Environment '" & env &
                   "' ended without matching begin statement."))
   of "par", "cr":
      handle_par(p)
      get_token(p)
   else:
      var name = p.tok.token
      get_token(p)
      if p.tok.catcode == 1:
         inc(p.delimiter_count)
         p.scope_entry = ScopeEntry(name: name, kind: ControlSequence,
                                    encl: Group, count: 1,
                                    delimiter_count: p.delimiter_count)
         begin_enclosure(p, false, contains(EXPANDED_CONTROL_WORDS, name),
                         context_before)
         get_token(p)
      elif p.tok.catcode == 12 and p.tok.token == "[" and
           not is_in_math_scope(p.seg):
         # We don't allow option enclosures in math scopes since it is far more
         # likely that the characters '[' and ']' are used not to indicate
         # options but as range specifiers. For example, "x \in [0.5, 1)" would
         # cause parse errors later on if we don't do this.
         p.scope_entry = ScopeEntry(name: name, kind: ControlSequence,
                                    encl: Option, count: 1)
         begin_enclosure(p, false, contains(EXPANDED_CONTROL_WORDS, name),
                         context_before)
         get_token(p)


proc parse_control_symbol(p: var LaTeXParser) =
   # TODO: Fix this indexing business?
   if p.tok.token[0] in ESCAPED_CHARACTERS:
      add_tok(p)
   elif p.tok.token == "\\":
      handle_par(p)
   elif p.tok.token == "[":
      # In LaTeX, '\[' is equivalent to plain TeX's '$$' which means that they
      # may be interchanged to begin and end displayed math sections. However,
      # the 'amsmath' package (which is widely used) redefines \[ to mean
      # '\begin{equation*}', whereby the constructions can no longer be
      # interchanged. Let's assume the user is a responsible adult and avoid
      # doing delimter pairing which would allow us to raise a parse error.
      p.scope_entry = ScopeEntry(kind: ScopeKind.Math,
                                 encl: Enclosure.DisplayMath)
      begin_enclosure(p, false, false, p.tok.context.before)
   elif p.tok.token == "]" and is_in_enclosure(p, Enclosure.DisplayMath):
      end_enclosure(p, p.tok.context.after)
   elif p.tok.token == "(":
      p.scope_entry = ScopeEntry(kind: ScopeKind.Math,
                                 encl: Enclosure.Math)
      begin_enclosure(p, false, false, p.tok.context.before)
   elif p.tok.token == ")" and is_in_enclosure(p, Enclosure.Math):
      end_enclosure(p, p.tok.context.after)

   get_token(p)


proc parse_comment(p: var LaTeXParser) =
   if starts_with(p.tok.token, "lins-enable"):
      p.is_enabled = true
   elif starts_with(p.tok.token, "lins-disable"):
      p.is_enabled = false
   else:
      var seg = LaTeXTextSegment()
      seg.base.text = p.tok.token
      seg.base.col = p.tok.col
      seg.base.line = p.tok.line
      seg.scope = @[ScopeEntry(kind: ScopeKind.Comment)]
      add_seg(p, seg)

   get_token(p)


proc parse_token(p: var LaTeXParser) =
   ## Eats tokens from the input stream until an end condition is reached.
   case p.tok.token_type
   of Character: parse_character(p)
   of ControlWord: parse_control_word(p)
   of ControlSymbol: parse_control_symbol(p)
   of Comment: parse_comment(p)
   else:
      # We should raise an exception if we're forced to parse a token that is
      # not one of the above. Currently, that's 'Invalid' and "EndOfFile'.
      log.abort(ParseError, attach_line(p.tok, "Parser encountered an " &
                "invalid token: " & $p.tok))


proc parse_all*(p: var LaTeXParser): seq[LaTeXTextSegment] =
   get_token(p)
   while p.tok.token_type != EndOfFile:
      parse_token(p)
   add_seg(p, p.seg)
   result = p.segs


proc parse_string*(s: string, filename: string = ""): seq[LaTeXTextSegment] =
   var p: LaTeXParser
   var ss = new_string_stream(s)
   open_parser(p, filename, ss)
   result = parse_all(p)
   close_parser(p)
