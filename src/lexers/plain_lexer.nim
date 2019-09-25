import lexbase
import streams

# This module implements a plain text lexer converting characters to tokens.
# In the spirit of TeX, newlines are removed a paragraph is inferred when.

type
   PlainTokenType* = enum
      Invalid
      EndOfFile
      Character
      ParagraphBreak

   PlainToken* = object
      token_type*: PlainTokenType
      token*: string
      line*, col*: int

   State = enum
      StateM # Appending characters
      StateN # Beginning of line

   PlainLexer* = object of BaseLexer
      filename: string
      state: State


proc init*(t: var PlainToken) =
   t.token_type = Invalid
   set_len(t.token, 0)
   t.line = 0
   t.col = 0


proc handle_crlf(l: var PlainLexer, pos: int): int =
   # Refill buffer at end-of-line characters.
   case l.buf[l.bufpos]
   of '\c':
      result = lexbase.handleCR(l, pos)
   of '\L':
      result = lexbase.handleLF(l, pos)
   else:
      result = pos


proc new*(t: typedesc[PlainToken], token_type: PlainTokenType,
          token: string, line, col: int): PlainToken =
   result = PlainToken(token_type: token_type,
                       token: token, line: line, col: col)


template update_token_position(l: PlainLexer, tok: var PlainToken) =
   tok.col = getColNumber(l, l.bufpos)
   tok.line = l.lineNumber


proc get_token*(l: var PlainLexer, tok: var PlainToken) =
   # Initialize the token
   tok.token_type = Invalid
   set_len(tok.token, 0)
   update_token_position(l, tok)

   let c = l.buf[l.bufpos]
   case c:
   of lexbase.EndOfFile:
      tok.token_type = EndOfFile
   of {'\c', '\L'}:
      let prev_state = l.state
      l.bufpos = handle_crlf(l, l.bufpos)
      l.state = StateN

      case prev_state:
      of StateN:
         tok.token_type = ParagraphBreak
      of StateM:
         tok.token_type = Character
         tok.token = " "
   else:
      tok.token_type = Character
      tok.token = $c
      l.state = StateM
      inc(l.bufpos)


proc open_lexer*(l: var PlainLexer, filename: string, s: Stream) =
   lexbase.open(l, s)
   l.filename = filename
   l.state = StateN


proc close_lexer*(l: var PlainLexer) =
   lexbase.close(l)
