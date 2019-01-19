import streams
import strutils

import ../lexers/plain_lexer
import ../utils/log
import ./base_parser

export ParseError

type
   PlainScopeEntry = object
      par_idx: int

   PlainParser* = object
      lex: PlainLexer
      tok: PlainToken
      seg: PlainTextSegment
      segs: seq[PlainTextSegment]
      last_tok: PlainToken
      par_idx: int

   PlainTextSegment* = object of TextSegment
      par_idx*: int


proc get_token*(p: var PlainParser) =
   get_token(p.lex, p.tok)


proc init(seg: var PlainTextSegment) =
   seg.par_idx = 0
   base_parser.init(seg)


proc open_parser*(p: var PlainParser, filename: string, s: Stream) =
   init(p.tok)
   init(p.last_tok)
   init(p.seg)
   set_len(p.segs, 0)
   p.par_idx = 0
   open_lexer(p.lex, filename, s)


proc close_parser*(p: var PlainParser) =
   close_lexer(p.lex)


proc add_tok(p: var PlainParser) =
   if len(p.seg.text) == 0:
      p.seg.line = p.tok.line
      p.seg.col = p.tok.col
   elif p.tok.line > p.last_tok.line:
      add(p.seg.linebreaks, (len(p.seg.text), p.tok.line))

   add(p.seg.text, p.tok.token)
   p.last_tok = p.tok


proc parse_character(p: var PlainParser) =
   add_tok(p)
   get_token(p)


proc parse_paragraph_break(p: var PlainParser) =
   add(p.segs, p.seg)
   inc(p.par_idx)
   p.seg = PlainTextSegment()
   p.seg.par_idx = p.par_idx
   get_token(p)


proc parse_token(p: var PlainParser) =
   ## Eats tokens from the input stream until an end condition is reached.
   case p.tok.token_type
   of Character: parse_character(p)
   of ParagraphBreak: parse_paragraph_break(p)
   else:
      # We should raise an exception if we're forced to parse a token that is
      # not one of the above. Currently, that's 'Invalid' and "EndOfFile'.
      log.abort(ParseError, "Parser encountered an invalid token: $1", $p.tok)


proc parse_all*(p: var PlainParser): seq[PlainTextSegment] =
   get_token(p)
   while p.tok.token_type != EndOfFile:
      parse_token(p)
   add(p.segs, p.seg)
   result = p.segs


proc parse_string*(s: string, filename: string = ""): seq[PlainTextSegment] =
   var p: PlainParser
   var ss = new_string_stream(s)
   open_parser(p, filename, ss)
   result = parse_all(p)
   close_parser(p)
