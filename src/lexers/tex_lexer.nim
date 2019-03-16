import lexbase
import streams
import strutils


type
   TeXTokenType* = enum
      Invalid
      EndOfFile
      ControlWord
      ControlSymbol
      Character
      Comment

   CategoryCode* = range[0 .. 15]

   Context* = tuple
      before, after: string

   TeXToken* = object
      token_type*: TeXTokenType
      catcode*: CategoryCode
      token*: string
      line*, col*: int
      context*: Context

   State = enum
      StateN
      StateM
      StateS

   TeXLexer* = object of BaseLexer
      filename: string
      state: State
      nof_context_chars: int
      context_carry: string


const
   CATEGORY: array[CategoryCode, set[char]] = [
      {'\\'},
      {'{'},
      {'}'},
      {'$'},
      {'&'},
      {'\c', '\L'},
      {'#'},
      {'^'},
      {'_'},
      {}, # Ignored characters
      {' ', '\t'},
      {'A' .. 'Z', 'a' .. 'z'},
      {}, # Category 12 contains any character not in the other sets
          # (handled as a special case).
      {'~'},
      {'%'},
      {'\x08'}
   ]


# Forward declaration
proc get_token*(l: var TeXLexer, tok: var TeXToken)


proc init*(t: var TeXToken) =
   t.token_type = Invalid
   t.catcode = 0
   set_len(t.token, 0)
   t.line = 0
   t.col = 0


proc is_valid*(t: TeXToken): bool =
   return t.token_type != Invalid


# TODO: This is a naive implementation that doesn't take unicode characters
# into account.
proc get_context_before(l: TeXLexer, pos: int): string =
   # If the buffer has been reset we need to get the context from the carry.
   if pos == 0:
      return l.context_carry

   var tmp = ""
   for i in countup(1, l.nof_context_chars):
      let c = l.buf[pos - i]
      if c == '\0':
         break
      else:
         add(tmp, c)

   for i in countdown(high(tmp), 0):
      add(result, tmp[i])


proc get_context_after(l: TeXLexer, pos: int): string =
   for i in countup(1, l.nof_context_chars):
      let c = l.buf[pos + i]
      if c == '\0':
         break
      else:
         add(result, c)


proc handle_crlf(l: var TeXLexer, pos: int): int =
   # Refill buffer at end-of-line characters. Store the context in case the
   # buffer is refilled completely, i.e. result is 0 leaving this proc.
   l.context_carry = get_context_before(l, l.bufpos)
   case l.buf[l.bufpos]
   of '\c':
      result = lexbase.handleCR(l, pos)
   of '\L':
      result = lexbase.handleLF(l, pos)
   else:
      result = pos


template update_token_position(l: TeXLexer, tok: var TeXToken) =
   tok.col = get_col_number(l, l.bufpos)
   tok.line = l.lineNumber


proc get_category_code(c: char): CategoryCode =
   result = 12
   for ccode, cset in CATEGORY:
      if c in cset:
         result = ccode
         break


proc is_quartet(l: TeXLexer, pos: int): bool =
   var buf = l.buf
   result = buf[pos] in CATEGORY[7] and buf[pos + 1] == buf[pos] and
            buf[pos + 2] in HexDigits and buf[pos + 3] in HexDigits


proc replace_quartet(l: var TeXLexer, pos: int): int =
   # The current buffer position is expected to point to the first character of
   # the quartet, e.g. ^^3A.
   assert(is_quartet(l, pos))
   let
      msnibble = l.buf[pos + 2]
      lsnibble = l.buf[pos + 3]

   # Insert replacement character at the position of the last character in
   # the quartet.
   l.buf[pos + 3] = char(parseHexInt(msnibble & lsnibble))
   result = pos + 3


proc is_trio(l: TeXLexer, pos: int): bool =
   var buf = l.buf
   result = buf[pos] in CATEGORY[7] and buf[pos + 1] == buf[pos] and
            int(buf[pos + 2]) < 128


proc replace_trio(l: var TeXLexer, pos: int): int =
   # The current buffer position is expected to point to the first character of
   # the trio, e.g. ^^J.
   assert(is_trio(l, pos))
   let c = l.buf[pos + 2]

   # Compute code adjustment according to p.45 of the TeXbook.
   var adjustment = 0
   if int(c) < 64:
      adjustment = 64
   else:
      adjustment = -64

   # Insert replacement character at the position of the last character
   # in the trio.
   l.buf[pos + 2] = char(int(c) + adjustment)
   result = pos + 2


proc is_replaceable(l: TeXLexer, pos: int): bool =
   return is_quartet(l, pos) or is_trio(l, pos)


proc handle_replacement(l: var TeXLexer, pos: int): int =
   if is_quartet(l, pos):
      result = replace_quartet(l, pos)
   elif is_trio(l, pos):
      result = replace_trio(l, pos)
   else:
      result = pos


proc handle_category_0(l: var TeXLexer, tok: var TeXToken) =
   var pos = l.bufpos + 1 # Skip '\'
   var buf = l.buf
   var state = l.state

   case buf[pos]
   of {'\c', '\L', lexbase.EndOfFile}:
      # Empty control sequence, buffer is refilled outside of this function as
      # long as we don't move past the CR/LF character. We also keep the current
      # state for this reason.
      set_len(tok.token, 0)
      tok.token_type = ControlWord
   of CATEGORY[11]:
      # If the next character is of category 11, we construct a control
      # word and move to state S.
      tok.token_type = ControlWord
      while buf[pos] in CATEGORY[11]:
         add(tok.token, buf[pos])
         inc(pos)
         # Handle trio/quartet replacement within the control word.
         pos = handle_replacement(l, pos)
      state = StateS
   of CATEGORY[10]:
      # If the next character is of category 10, we construct a control
      # space and move to state S.
      tok.token_type = ControlSymbol
      add(tok.token, buf[pos])
      inc(pos)
      state = StateS
   else:
      if is_replaceable(l, pos):
         # Handle trio/quartet replacement at the start of a control sequence.
         l.bufpos = handle_replacement(l, pos)
         dec(l.bufpos) # Account for initial + 1 by handle_category_0
         handle_category_0(l, tok)
         pos = l.bufpos
         state = l.state
      else:
         # For any other character, we construct a control symbol and move to
         # state M. We have to attach the trailing context to these tokens too
         # since they are often used as environment delimiters.
         tok.token_type = ControlSymbol
         tok.context.after = get_context_after(l, pos)
         add(tok.token, buf[pos])
         inc(pos)
         state = StateM

   l.bufpos = pos
   l.state = state


proc handle_category_7(l: var TeXLexer, tok: var TeXToken) =
   var pos = l.bufpos

   if is_replaceable(l, pos):
      l.bufpos = handle_replacement(l, pos)
      get_token(l, tok)
      pos = l.bufpos
   else:
      # Regular superscript character, append and move to state M.
      tok.token_type = Character
      tok.token = $l.buf[pos]
      tok.catcode = 7
      inc(pos)
      l.state = StateM

   l.bufpos = pos


proc handle_category_14(l: var TeXLexer, tok: var TeXToken) =
   # Skip over the comment character and leading whitespace, making sure to
   # break on EOF/newline. After that: update the token's position.
   inc(l.bufpos)
   while l.buf[l.bufpos] in {' ', '\t'} and
         l.buf[l.bufpos] notin {lexbase.EndOfFile, '\L', '\c'}:
      inc(l.bufpos)
   update_token_position(l, tok)

   var str = ""
   while l.buf[l.bufpos] notin {lexbase.EndOfFile, '\L', '\c'}:
      add(str, l.buf[l.bufpos])
      inc(l.bufpos)
   l.bufpos = handle_crlf(l, l.bufpos)
   l.state = StateN

   # If the comment contained any characters, we return those as one single
   # 'Comment' token. Otherwise, we recursively call get_token().
   if len(str) > 0:
      tok.token = str
      tok.token_type = Comment
   else:
      get_token(l, tok)


proc get_token*(l: var TeXLexer, tok: var TeXToken) =
   # Initialize the token
   tok.token_type = Invalid
   tok.catcode = 0
   set_len(tok.token, 0)
   update_token_position(l, tok)
   set_len(tok.context.before, 0)
   set_len(tok.context.after, 0)

   let c = l.buf[l.bufpos]
   case c
   of lexbase.EndOfFile:
      tok.token_type = EndOfFile
   of CATEGORY[0]:
      # Grab the context before tokens of category code 0.
      tok.context.before = get_context_before(l, l.bufpos)
      handle_category_0(l, tok)
   of CATEGORY[5]:
      let prev_state = l.state
      l.bufpos = handle_crlf(l, l.bufpos)
      l.state = StateN

      case prev_state:
      of StateN:
         tok.token_type = ControlWord
         tok.token = "par"
      of StateM:
         tok.token_type = Character
         tok.token = " "
         tok.catcode = 10
      of StateS:
         # The end of line character is simply dropped and does not generate a
         # token. The buffer is refilled since before so we recursively call
         # get_token() to continue the search.
         get_token(l, tok)
   of CATEGORY[7]:
      handle_category_7(l, tok)
   of CATEGORY[9]:
      # Ignored characters, silently bypass.
      inc(l.bufpos)
      get_token(l, tok)
   of CATEGORY[10]:
      case l.state:
      of StateN, StateS:
         # Ignore the current character and recusively call get_token().
         inc(l.bufpos)
         get_token(l, tok)
      of StateM:
         tok.token_type = Character
         tok.token = " "
         tok.catcode = 10
         l.state = StateS
         inc(l.bufpos)
   of CATEGORY[14]:
      handle_category_14(l, tok)
   of CATEGORY[15]:
      # Invalid character (TeX would print an error, should we do the same?).
      # Ignore the character for now.
      inc(l.bufpos)
      get_token(l, tok)
   else:
      # A character of category 12, i.e. the class of 'other' characters.
      tok.token_type = Character
      tok.catcode = get_category_code(c)
      tok.token = $c
      l.state = StateM

      # Category 12 is implied for the characters '[' and ']'. This is the only
      # point where we have to venture into the LaTeX domain and offer context
      # to the characters '[' and ']'. These characters don't mean anything
      # special in plain TeX but is commonly used for option enclosures in
      # LaTeX. We could make the lexer agnostic to this but that would mean
      # attaching context to every token which is a relatively expensive
      # operation, especially if the context consists of 10-20 characters or
      # more. This is a trade-off worth making.
      if tok.catcode in [1, 3] or tok.token == "[":
         tok.context.before = get_context_before(l, l.bufpos)
      if tok.catcode in [2, 3] or tok.token == "]":
         tok.context.after = get_context_after(l, l.bufpos)

      inc(l.bufpos)


proc open_lexer*(l: var TeXLexer, filename: string, nof_context_chars: int,
                 s: Stream) =
   lexbase.open(l, s)
   l.filename = filename
   l.state = StateN
   l.nof_context_chars = nof_context_chars
   set_len(l.context_carry, 0)


proc close_lexer*(l: var TeXLexer) =
   lexbase.close(l)
