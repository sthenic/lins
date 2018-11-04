import streams
import strutils

import ../lexers/tex_lexer


type
   LaTeXParser = object
      lex*: TeXLexer
      tok*: TeXToken


proc get_token*(p: var LaTeXParser) =
   ## Get the next token from the lexer and store it in the `tok` member.
   tex_lexer.get_token(p.lex, p.tok)


proc open_parser*(p: var LaTeXParser, filename: string, s: Stream) =
   init(p.tok)
   open_lexer(p.lex, filename, s)


proc close_parser*(p: var LaTeXParser) =
   close_lexer(p.lex)
