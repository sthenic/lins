import streams
import strutils

import ../lexers/tex_lexer
import ../utils/log
import ./base_parser


type
   LaTeXParseError* = object of ParseError

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

   ScopeEntry* = object
      name*: string
      kind*: ScopeKind
      encl*: Enclosure
      count*: int

   LaTeXParser* = object
      lex: TeXLexer
      tok: TeXToken
      seg: LaTeXTextSegment # Segment under construction
      seg_stack: seq[LaTeXTextSegment] # Incomplete segments
      segs: seq[LaTeXTextSegment] # Completed segments
      scope: seq[ScopeEntry] # Complete scope
      scope_entry: ScopeEntry # Scope entry under construction
      last_tok: TeXToken
      delimiter_count: int # Delimiter count

   LaTeXTextSegment* = object of TextSegment
      scope*: seq[ScopeEntry]
      expand*: bool


const ESCAPED_CHARACTERS: set[char] = {'%', '&', '_', '#', '$', '~'}
const EXPANDED_CONTROL_WORDS: seq[string] = @["emph", "textbf", "texttt"]
const EXPANDED_ENVIRONMENTS: seq[string] = @[]

# Forward declarations
proc parse_character(p: var LaTeXParser)
proc parse_token(p: var LaTeXParser)


proc is_empty[T](s: seq[T]): bool =
   return s == @[]


proc is_empty(s: ScopeEntry): bool =
   return s.kind == ScopeKind.Invalid


proc is_in_enclosure(p: LaTeXParser, encl: Enclosure): bool =
   return not is_empty(p.scope) and p.scope[^1].encl == encl


proc get_token*(p: var LaTeXParser) =
   ## Get the next token from the lexer and store it in the `tok` member.
   get_token(p.lex, p.tok)


proc open_parser*(p: var LaTeXParser, filename: string, s: Stream) =
   init(p.tok)
   open_lexer(p.lex, filename, s)


proc close_parser*(p: var LaTeXParser) =
   close_lexer(p.lex)


proc add_tok(p: var LaTeXParser) =
   if len(p.seg.text) == 0:
      p.seg.line = p.tok.line
      p.seg.col = p.tok.col
   elif p.tok.line > p.last_tok.line:
      add(p.seg.linebreaks, (len(p.seg.text), p.tok.line))

   add(p.seg.text, p.tok.token)
   p.last_tok = p.tok


proc add_seg(p: var LaTeXParser, seg: LaTeXTextSegment) =
   ## Add a segment to the sequence of completed segments.
   if len(seg.text.strip()) != 0:
      # We skip adding segments with length zero or consisting entirely of
      # whitespace.
      add(p.segs, seg)


proc begin_enclosure(p: var LaTeXParser, keep_scope, expand: bool) =
   # Push the current text segment to the stack.
   add(p.seg_stack, p.seg)
   # Push the current scope entry to the scope.
   add(p.scope, p.scope_entry)
   # Initialize a new text segment w/ the current scope.
   p.seg = LaTeXTextSegment()
   p.seg.scope = p.scope
   p.seg.expand = expand
   # Initialize a new scope entry unless we're told to keep it. This only
   # happens when an environment is entered since there may be options and
   # capture groups following the \begin{env} statement.
   if not keep_scope:
      p.scope_entry = ScopeEntry()


proc expand_segment(p: var LaTeXParser, inner: LaTeXTextSegment) =
   # The inner segment should be 'expanded' and thus added to the outer text
   # segment. All the linebreaks of the inner segment gets added to the
   # outer with modified positions (their coordinates are absolute). If the
   # outer segment has length zero, we also pass on the segment starting
   # position.
   let outer_len = len(p.seg.text)
   if outer_len == 0:
      p.seg.line = inner.line
      p.seg.col = inner.col
   for lb in inner.linebreaks:
      add(p.seg.linebreaks, (outer_len + lb.pos, lb.line))
   add(p.seg.text, inner.text)


proc end_enclosure(p: var LaTeXParser) =
   let inner = p.seg
   p.seg = pop(p.seg_stack)
   if inner.expand:
      # Pop the text segment stack and expand the inner segment into the outer
      # segment.
      expand_segment(p, inner)
   else:
      # Otherwise, the segment is not to be expanded so we just add the segment
      # to the list of completed segments.
      add_seg(p, inner)
   # Restore the scope entry.
   p.scope_entry = pop(p.scope)


proc handle_par(p: var LaTeXParser) =
   # The current text segment should end here and be added to the list of
   # completed text segments. However, if this segment should be expanded we
   # add the partial result to the outer segment and push the outer segment
   # back onto the stack.
   let inner = p.seg
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


proc clear_scope(p: var LaTeXParser) =
   p.scope_entry = ScopeEntry()


proc handle_category_1(p: var LaTeXParser) =
   # Beginning of group character. If the current scope entry is empty, this
   # group does not belong to any object.  Additionally, we keep track of the
   # delimiter count within the segment.
   if not is_empty(p.scope_entry):
      p.scope_entry = ScopeEntry(name: p.scope_entry.name,
                                 kind: p.scope_entry.kind,
                                 encl: Group,
                                 count: p.scope_entry.count + 1)
      begin_enclosure(p, false, false)
   else:
      inc(p.delimiter_count)
   get_token(p)


proc handle_category_2(p: var LaTeXParser) =
   # Handle end of group characters.
   if is_in_enclosure(p, Group) and p.delimiter_count == 0:
      end_enclosure(p)
   else:
      dec(p.delimiter_count)
   get_token(p)


proc handle_category_3(p: var LaTeXParser) =
   # Handle math shift characters.
   if is_in_enclosure(p, Enclosure.DisplayMath):
      # Ends with the next character.
      end_enclosure(p)
      get_token(p)
      if p.tok.catcode != 3:
         # Error condition.
         raise new_exception(LaTeXParseError, "Display math section ended " &
                             "without two characters of catcode 3, e.g. '$$'.")
      get_token(p)
   elif is_in_enclosure(p, Enclosure.Math):
      # Ends with this character.
      end_enclosure(p)
      get_token(p)
   else:
      # Enclosure begins, peek the next character to determine the type
      # of math enclosure. For display math, TeX requires that the '$$'
      # delimiter occurs next to each other.
      get_token(p)
      if p.tok.catcode == 3:
         p.scope_entry = ScopeEntry(kind: ScopeKind.Math,
                                    encl: Enclosure.DisplayMath)
         begin_enclosure(p, false, false)
         get_token(p)
      else:
         p.scope_entry = ScopeEntry(kind: ScopeKind.Math,
                                    encl: Enclosure.Math)
         begin_enclosure(p, false, false)
         # Recursively parse the token.
         parse_token(p)


proc handle_category_12(p: var LaTeXParser) =
   # Handle 'other' characters.
   if p.tok.token == "[" and not is_empty(p.scope_entry):
      p.scope_entry = ScopeEntry(name: p.scope_entry.name,
                                 kind: p.scope_entry.kind,
                                 encl: Option,
                                 count: p.scope_entry.count + 1)
      begin_enclosure(p, false, false)
   elif p.tok.token == "]" and is_in_enclosure(p, Option):
      end_enclosure(p)
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
      clear_scope(p)
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
            raise new_exception(LaTeXParseError, "Unexpected end of file " &
                                "when parsing capture group.")
         else:
            add(result, p.tok.token)
         if count == 0:
            break
   else:
      add(result, p.tok.token)


proc parse_control_word(p: var LaTeXParser) =
   case p.tok.token
   of "begin":
      let env = get_group_as_string(p) # Stops at '}'
      p.scope_entry = ScopeEntry(name: env, kind: ScopeKind.Environment,
                                 encl: Enclosure.Environment)
      begin_enclosure(p, true, contains(EXPANDED_ENVIRONMENTS, env))
      get_token(p)
   of "end":
      let env = get_group_as_string(p) # Stops at '}'
      if is_in_enclosure(p, Enclosure.Environment):
         end_enclosure(p)
         if p.scope_entry.name != env:
            raise new_exception(LaTeXParseError, "Environment name mismatch '" &
                                env & "' closes '" & p.scope_entry.name & "'.")
         clear_scope(p)
         get_token(p) # Scan over '}'
      else:
         raise new_exception(LaTeXParseError, "Environment " & env &
                             "ended without matching begin statement.")
   of "par":
      handle_par(p)
      get_token(p)
   else:
      var name = p.tok.token
      get_token(p)
      if p.tok.catcode == 1:
         p.scope_entry = ScopeEntry(name: name, kind: ControlSequence,
                                    encl: Group, count: 1)
         begin_enclosure(p, false, contains(EXPANDED_CONTROL_WORDS, name))
         get_token(p)
      elif p.tok.catcode == 12 and p.tok.token == "[":
         p.scope_entry = ScopeEntry(name: name, kind: ControlSequence,
                                    encl: Option, count: 1)
         begin_enclosure(p, false, contains(EXPANDED_CONTROL_WORDS, name))
         get_token(p)


proc parse_control_symbol(p: var LaTeXParser) =
   # TODO: Fix this indexing business?
   if p.tok.token[0] in ESCAPED_CHARACTERS:
      add_tok(p)
   elif p.tok.token == "[":
      # In LaTeX, '\[' is equivalent to plain TeX's '$$' which means that they
      # may be interchanged to begin and end displayed math sections. However,
      # the 'amsmath' package (which is widely used) redefines \[ to mean
      # '\begin{equation*}', whereby the constructions can no longer be
      # interchanged. Let's assume the user is a responsible adult and avoid
      # doing delimter pairing which would allow us to raise a parse error.
      p.scope_entry = ScopeEntry(kind: ScopeKind.Math,
                                 encl: Enclosure.DisplayMath)
      begin_enclosure(p, false, false)
   elif p.tok.token == "]" and is_in_enclosure(p, Enclosure.DisplayMath):
      end_enclosure(p)
   elif p.tok.token == "(":
      p.scope_entry = ScopeEntry(kind: ScopeKind.Math,
                                 encl: Enclosure.Math)
      begin_enclosure(p, false, false)
   elif p.tok.token == ")" and is_in_enclosure(p, Enclosure.Math):
      end_enclosure(p)

   get_token(p)


proc parse_token(p: var LaTeXParser) =
   ## Eats tokens from the input stream until an end condition is reached.
   case p.tok.token_type
   of Character: parse_character(p)
   of ControlWord: parse_control_word(p)
   of ControlSymbol: parse_control_symbol(p)
   else:
      # We should raise an exception if we're forced to parse a token that is
      # not one of the above. Currently, that's 'Invalid' and "EndOfFile'.
      raise new_exception(LaTeXParseError,
                          "Parser encountered an invalid token: " & $p.tok)


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
