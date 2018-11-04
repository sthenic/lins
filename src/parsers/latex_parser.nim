import strutils

import ../lexers/tex_lexer

type
   LaTeXParser = object
      lex*: TeXLexer
      tok*: TeXToken
