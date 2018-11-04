import lexbase
import streams
import strutils
import unicode


type
   TokenType* {.pure.} = enum
      Invalid
      EndOfFile
      ControlWord
      ControlSymbol
      Character

   CategoryCode* = range[0 .. 15]

   Token* = object
      token_type*: TokenType
      catcode: CategoryCode
      token*: string
      line, col: int

   State = enum
      StateN
      StateM
      StateS

   Lexer* = object of BaseLexer
      filename: string
      state: State


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
proc get_token(l: var Lexer, tok: var Token)


proc handle_crlf(l: var Lexer, pos: int): int =
   # Refill buffer at end-of-line characters.
   case l.buf[l.bufpos]
   of '\c':
      result = lexbase.handleCR(l, pos)
   of '\L':
      result = lexbase.handleLF(l, pos)
   else:
      result = pos


template update_token_position(l: Lexer, tok: var Token) =
   tok.col = getColNumber(l, l.bufpos)
   tok.line = l.lineNumber


proc get_category_code(c: char): CategoryCode =
   result = 12
   for ccode, cset in CATEGORY:
      if c in cset:
         result = ccode
         break


proc is_quartet(l: Lexer, pos: int): bool =
   var buf = l.buf
   result = buf[pos] in CATEGORY[7] and buf[pos + 1] == buf[pos] and
            buf[pos + 2] in HexDigits and  buf[pos + 3] in HexDigits


proc replace_quartet(l: var Lexer, pos: int): int =
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


proc is_trio(l: Lexer, pos: int): bool =
   var buf = l.buf
   result = buf[pos] in CATEGORY[7] and buf[pos + 1] == buf[pos] and
            int(buf[pos + 2]) < 128


proc replace_trio(l: var Lexer, pos: int): int =
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


proc is_replaceable(l: Lexer, pos: int): bool =
   return is_quartet(l, pos) or is_trio(l, pos)


proc handle_replacement(l: var Lexer, pos: int): int =
   if is_quartet(l, pos):
      result = replace_quartet(l, pos)
   elif is_trio(l, pos):
      result = replace_trio(l, pos)
   else:
      result = pos


proc handle_category_0(l: var Lexer, tok: var Token) =
   var pos = l.bufpos + 1 # Skip '\'
   var buf = l.buf
   var state = l.state

   case buf[pos]
   of {'\c', '\L', lexbase.EndOfFile}:
      # Empty control sequence, buffer is refilled outside of this function as
      # long as we don't move past the CR/LF character. We also keep the current
      # state for this reason.
      set_len(tok.token, 0)
      tok.token_type = TokenType.ControlWord
   of CATEGORY[11]:
      # If the next character is of category 11, we construct a control
      # word and move to state S.
      tok.token_type = TokenType.ControlWord
      while buf[pos] in CATEGORY[11]:
         add(tok.token, buf[pos])
         inc(pos)
         # Handle trio/quartet replacement within the control word.
         pos = handle_replacement(l, pos)
      state = StateS
   of CATEGORY[10]:
      # If the next character is of category 10, we construct a control
      # space and move to state S.
      tok.token_type = TokenType.ControlSymbol
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
         # state M.
         tok.token_type = TokenType.ControlSymbol
         add(tok.token, buf[pos])
         inc(pos)
         state = StateM

   l.bufpos = pos
   l.state = state


proc handle_category_7(l: var Lexer, tok: var Token) =
   var pos = l.bufpos

   if is_replaceable(l, pos):
      l.bufpos = handle_replacement(l, pos)
      get_token(l, tok)
      pos = l.bufpos
   else:
      # Regular superscript character
      tok.token_type = TokenType.Character
      tok.token = $l.buf[pos]
      tok.catcode = 7
      inc(pos)

   l.bufpos = pos


proc get_token(l: var Lexer, tok: var Token) =
   # Initialize the token
   tok.token_type = TokenType.Invalid
   tok.catcode = 0
   set_len(tok.token, 0)
   update_token_position(l, tok)

   let c = l.buf[l.bufpos]
   case c:
   of lexbase.EndOfFile:
      tok.token_type = TokenType.EndOfFile
   of CATEGORY[0]:
      handle_category_0(l, tok)
   of CATEGORY[5]:
      let prev_state = l.state
      l.bufpos = handle_crlf(l, l.bufpos)
      l.state = StateN

      case prev_state:
      of StateN:
         tok.token_type = TokenType.ControlWord
         tok.token = "par"
      of StateM:
         tok.token_type = TokenType.Character
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
         tok.token_type = TokenType.Character
         tok.token = " "
         tok.catcode = 10
         l.state = StateS
         inc(l.bufpos)
   of CATEGORY[14]:
      # Comment character. Ultimately we should write a function to handle
      # special comments which may pass information to the upper layers, e.g.
      # the parser. Right now, throw away everything until the next newline.
      while l.buf[l.bufpos] notin {lexbase.EndOfFile, '\L', '\c'}:
         inc(l.bufpos)
      l.bufpos = handle_crlf(l, l.bufpos)
      l.state = StateN
      get_token(l, tok)
   of CATEGORY[15]:
      # Invalid character (TeX would print an error, should we do the same?).
      # Ignore the character for now.
      inc(l.bufpos)
      get_token(l, tok)
   of CATEGORY[1] + CATEGORY[2] + CATEGORY[3] + CATEGORY[4] + CATEGORY[6] +
      CATEGORY[8] + CATEGORY[11] + CATEGORY[13]:
      tok.token_type = TokenType.Character
      tok.catcode = get_category_code(c)
      tok.token = $c
      l.state = StateM
      inc(l.bufpos)
   else:
      # A character of category 12, i.e. the class of 'other' characters.
      tok.token_type = TokenType.Character
      tok.catcode = 12
      tok.token = $c
      l.state = StateM
      inc(l.bufpos)


proc lex*(s: Stream) =
   var lx: Lexer
   var tok: Token
   lx.state = StateN

   lexbase.open(lx, s)

   while true:
      get_token(lx, tok)
      echo "Got token ", tok
      if tok.token_type == TokenType.EndOfFile:
         break

   lexbase.close(lx)
