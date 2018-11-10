import streams
import strutils

import ../lexers/tex_lexer
import ../utils/log


type
   Enclosure {.pure.} = enum
      Invalid
      Option
      Group
      Environment

   ScopeKind {.pure.} = enum
      Invalid
      ControlSequence
      Environment

   ScopeEntry = object
      name: string
      kind: ScopeKind
      enclosure: Enclosure
      count: int

   LaTeXParser* = object
      lex: TeXLexer
      tok: TeXToken
      seg: TextSegment
      seg_stack: seq[TextSegment]
      scope: seq[ScopeEntry]
      scope_entry: ScopeEntry
      add_offset_pt: bool

   OffsetPoint = tuple
      pos, line, col: int

   TextSegment* = object
      text: string
      line, col: int
      offset_pts: seq[OffsetPoint]
      scope: seq[ScopeEntry]


const ESCAPED_CHARACTERS: set[char] = {'%', '&'}


proc is_empty[T](s: seq[T]): bool =
   return s == @[]


proc is_empty(s: ScopeEntry): bool =
   return s.kind == ScopeKind.Invalid


proc is_in_enclosure(p: LaTeXParser, encl: Enclosure): bool =
   return not is_empty(p.scope) and p.scope[^1].enclosure == encl


proc get_token*(p: var LaTeXParser) =
   ## Get the next token from the lexer and store it in the `tok` member.
   get_token(p.lex, p.tok)


proc open_parser*(p: var LaTeXParser, filename: string, s: Stream) =
   init(p.tok)
   open_lexer(p.lex, filename, s)


proc close_parser*(p: var LaTeXParser) =
   close_lexer(p.lex)


template pop_if_update(s: seq[OffsetPoint], pt: OffsetPoint) =
   if not is_empty(s) and s[^1].pos == pt.pos:
      discard pop(s)


proc add_tok(p: var LaTeXParser) =
   if len(p.seg.text) == 0:
      p.seg.line = p.tok.line
      p.seg.col = p.tok.col

   if p.add_offset_pt:
      let pt: OffsetPoint = (len(p.seg.text), p.tok.line, p.tok.col)
      pop_if_update(p.seg.offset_pts, pt)
      add(p.seg.offset_pts, pt)
      p.add_offset_pt = false
   add(p.seg.text, p.tok.token)


proc begin_enclosure(p: var LaTeXParser, keep_scope: bool) =
   # Push the current text segment to the stack.
   add(p.seg_stack, p.seg)
   # Push the current scope entry to the scope.
   add(p.scope, p.scope_entry)
   # Initialize a new text segment w/ the current scope.
   p.seg = TextSegment()
   p.seg.scope = p.scope
   # Initialize a new scope entry unless we're told to keep it. This only
   # happens when an environment is entered since there may be options and
   # capture groups following the \begin{env} statement.
   if not keep_scope:
      p.scope_entry = ScopeEntry()


proc end_enclosure(p: var LaTeXParser) =
   # Emit the text segment.
   echo "Enclosure ended, emitting text segment ", p.seg
   # Pop the text segment stack.
   p.seg = pop(p.seg_stack)
   # TODO: Maybe this +1 should be removed, depends on what is assumed about the
   #       parser when this function is entered.
   let pt: OffsetPoint = (len(p.seg.text), p.tok.line, p.tok.col + 1)
   pop_if_update(p.seg.offset_pts, pt)
   add(p.seg.offset_pts, pt)
   # Restore the scope entry.
   p.scope_entry = pop(p.scope)


proc clear_scope(p: var LaTeXParser) =
   p.scope_entry = ScopeEntry()


proc parse_character(p: var LaTeXParser) =
   var add_token = true
   # A character token gets added to the text segment except in a few cases.
   # TODO: Maybe detect unbalanced grouping characters.
   case p.tok.catcode
   of 1:
      # Beginning of group character. If the current scope entry is empty, this
      # group does not belong to any object. We ignore the character but
      # indicate that the next character added to the text segment should add
      # an offset point.
      if not is_empty(p.scope_entry):
         p.scope_entry = ScopeEntry(name: p.scope_entry.name,
                                    kind: p.scope_entry.kind,
                                    enclosure: Group,
                                    count: p.scope_entry.count + 1)
         begin_enclosure(p, false)
      else:
         p.add_offset_pt = true
      add_token = false
   of 2:
      if is_in_enclosure(p, Group):
         end_enclosure(p)
      else:
         p.add_offset_pt = true
      add_token = false
   of 12:
      if p.tok.token == "[" and not is_empty(p.scope_entry):
         p.scope_entry = ScopeEntry(name: p.scope_entry.name,
                                    kind: p.scope_entry.kind,
                                    enclosure: Option,
                                    count: p.scope_entry.count + 1)
         begin_enclosure(p, false)
         add_token = false
         p.add_offset_pt = true
      elif p.tok.token == "]" and is_in_enclosure(p, Option):
         end_enclosure(p)
         add_token = false
         p.add_offset_pt = true
   else:
      clear_scope(p)

   if add_token:
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
            echo "Unexpected end of file." # TODO: Error handling
            break
         else:
            add(result, p.tok.token)
         if count == 0:
            break
   else:
      add(result, p.tok.token)


proc parse_control_word(p: var LaTeXParser) =
   # p.cs.pos = (p.tok.line, p.tok.col)
   # p.cs.name = p.tok.token
   case p.tok.token
   of "begin":
      let env = get_group_as_string(p)
      # p.cs.name = env
      p.scope_entry = ScopeEntry(name: env, kind: ScopeKind.Environment,
                                 enclosure: Enclosure.Environment)
      begin_enclosure(p, true)
      get_token(p)
   of "end":
      # TODO: Create bool testing functions for these kinds of expressions, i.e.
      #       checking if the scope is empty and if not, validating the
      #       enclosure closing conditions.
      if is_in_enclosure(p, Enclosure.Environment):
         let env = get_group_as_string(p) # Stops at '}'
         end_enclosure(p)
         clear_scope(p)
         get_token(p) # Scan over '}'
         if p.scope_entry.name != env:
            echo "Environment name mismatch"
         else:
            echo "Closed matched environment"
      else:
         echo "lonely environment end"
         get_token(p)
   else:
      var name = p.tok.token
      get_token(p)
      if p.tok.catcode == 1:
         p.scope_entry = ScopeEntry(name: name, kind: ControlSequence,
                                    enclosure: Group, count: 1)
         begin_enclosure(p, false)
         get_token(p)
      elif p.tok.catcode == 12 and p.tok.token == "[":
         p.scope_entry = ScopeEntry(name: name, kind: ControlSequence,
                                    enclosure: Option, count: 1)
         begin_enclosure(p, false)
         get_token(p)


proc parse_control_symbol(p: var LaTeXParser) =
   # TODO: Fix this indexing business?
   if p.tok.token[0] in ESCAPED_CHARACTERS:
      add_tok(p)
   # TODO: \[ \] opens a math environment, handle that.
   get_token(p)


proc parse_token(p: var LaTeXParser) =
   ## Eats tokens from the input stream until an end condition is reached.
   case p.tok.token_type
   of Character: parse_character(p)
   of ControlWord: parse_control_word(p)
   of ControlSymbol: parse_control_symbol(p)
   else:
      # Seems to parse the first invalid token
      echo "Some error!", p.tok
      get_token(p)


proc parse_all*(p: var LaTeXParser) =
   get_token(p)
   while p.tok.token_type != EndOfFile:
      parse_token(p)
   echo "Completed parsing, last text segment: ", p.seg


proc parse_string*(s: string, filename: string = ""): seq[TextSegment] =
   var p: LaTeXParser
   var ss = new_string_stream(s)
   open_parser(p, filename, ss)
   parse_all(p)
   close_parser(p)
