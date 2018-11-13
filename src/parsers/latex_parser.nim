import streams
import strutils

import ../lexers/tex_lexer
import ../utils/log

# TODO: Think about if it's worth tracking all the column positions what with
#       TeX eating additional whitespace etc. Any person would be able to track
#       down an issue given just the line number.


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
      encl: Enclosure
      count: int

   LaTeXParser* = object
      lex: TeXLexer
      tok: TeXToken
      seg: TextSegment # Segment under construction
      seg_stack: seq[TextSegment] # Incomplete segments
      segs: seq[TextSegment] # Completed segments
      scope: seq[ScopeEntry] # Complete scope
      scope_entry: ScopeEntry # Scope entry under construction
      last_tok: TeXToken
      delimiter_count: int # Delimiter count

   Linebreak* = tuple
      pos, line: int

   TextSegment* = object
      text*: string
      line*, col*: int
      linebreaks*: seq[Linebreak]
      scope*: seq[ScopeEntry]
      expand*: bool


const ESCAPED_CHARACTERS: set[char] = {'%', '&', '_', '#', '$'}
const EXPANDED_CONTROL_WORDS: seq[string] = @["emph", "textbf", "texttt"]
const EXPANDED_ENVIRONMENTS: seq[string] = @[]


proc new*(t: typedesc[TextSegment], text: string, line, col: int,
          linebreaks: seq[Linebreak], scope: seq[ScopeEntry],
          expand: bool = false): TextSegment =
   result = TextSegment(text: text, line: line, col: col,
                        linebreaks: linebreaks, scope: scope, expand: expand)


proc new*(t: typedesc[ScopeEntry], name: string, kind: ScopeKind,
          encl: Enclosure, count: int): ScopeEntry =
   result = ScopeEntry(name: name, kind: kind, encl: encl, count: count)


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
      let lb: Linebreak = (len(p.seg.text), p.tok.line)
      add(p.seg.linebreaks, lb)

   add(p.seg.text, p.tok.token)
   p.last_tok = p.tok


proc begin_enclosure(p: var LaTeXParser, keep_scope, expand: bool) =
   # Push the current text segment to the stack.
   add(p.seg_stack, p.seg)
   # Push the current scope entry to the scope.
   add(p.scope, p.scope_entry)
   # Initialize a new text segment w/ the current scope.
   p.seg = TextSegment()
   p.seg.scope = p.scope
   p.seg.expand = expand
   # Initialize a new scope entry unless we're told to keep it. This only
   # happens when an environment is entered since there may be options and
   # capture groups following the \begin{env} statement.
   if not keep_scope:
      p.scope_entry = ScopeEntry()


proc end_enclosure(p: var LaTeXParser) =
   # Emit the text segment.
   var inner = p.seg
   # Pop the text segment stack.
   p.seg = pop(p.seg_stack)
   if inner.expand:
      # The completed segment should be expanded and added to the outer text
      # segment. All the linebreaks of the inner segment gets added to the
      # outer with modified positions (their coordinates are absolute).
      let outer_len = len(p.seg.text)
      for lb in inner.linebreaks:
         add(p.seg.linebreaks, (outer_len + lb.pos, lb.line))
      add(p.seg.text, inner.text)
   else:
      add(p.segs, inner)
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
      add_token = false
   of 2:
      if is_in_enclosure(p, Group) and p.delimiter_count == 0:
         end_enclosure(p)
      else:
         dec(p.delimiter_count)
      add_token = false
   of 12:
      if p.tok.token == "[" and not is_empty(p.scope_entry):
         p.scope_entry = ScopeEntry(name: p.scope_entry.name,
                                    kind: p.scope_entry.kind,
                                    encl: Option,
                                    count: p.scope_entry.count + 1)
         begin_enclosure(p, false, false)
         add_token = false
      elif p.tok.token == "]" and is_in_enclosure(p, Option):
         end_enclosure(p)
         add_token = false
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
   case p.tok.token
   of "begin":
      let env = get_group_as_string(p)
      p.scope_entry = ScopeEntry(name: env, kind: ScopeKind.Environment,
                                 encl: Enclosure.Environment)
      begin_enclosure(p, true, contains(EXPANDED_ENVIRONMENTS, env))
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
            echo "Environment name mismatch ", env, " != ", p.scope_entry.name
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


proc parse_all*(p: var LaTeXParser): seq[TextSegment] =
   get_token(p)
   while p.tok.token_type != EndOfFile:
      parse_token(p)
   add(p.segs, p.seg)
   result = p.segs


proc parse_string*(s: string, filename: string = ""): seq[TextSegment] =
   var p: LaTeXParser
   var ss = new_string_stream(s)
   open_parser(p, filename, ss)
   result = parse_all(p)
   close_parser(p)
