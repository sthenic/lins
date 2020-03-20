import streams
import strutils

import ../lexers/plain_lexer
import ../utils/log
import ./base_parser

export ParseError, TextSegment

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

   PlainTextSegment* = object
      par_idx*: int
      base*: TextSegment


proc get_token*(p: var PlainParser) =
   get_token(p.lex, p.tok)


proc init(seg: var PlainTextSegment) =
   seg.par_idx = 0
   init(seg.base)


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
   if len(p.seg.base.text) == 0:
      p.seg.base.line = p.tok.line
      p.seg.base.col = p.tok.col
   elif p.tok.line > p.last_tok.line:
      add(p.seg.base.linebreaks, (len(p.seg.base.text), p.tok.line))

   add(p.seg.base.text, p.tok.token)
   p.last_tok = p.tok


proc add_seg(p: var PlainParser, seg: var PlainTextSegment) =
   ## Add a segment to the sequence of completed segments.
   if len(seg.base.text.strip()) != 0:
      # We skip adding segments with length zero or consisting entirely of
      # whitespace.
      add(p.segs, seg)


proc parse_character(p: var PlainParser) =
   add_tok(p)
   get_token(p)


proc parse_paragraph_break(p: var PlainParser) =
   add_seg(p, p.seg)
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
   add_seg(p, p.seg)
   result = p.segs


proc parse_string*(s: string, filename: string = ""): seq[PlainTextSegment] =
   var p: PlainParser
   var ss = new_string_stream(s)
   open_parser(p, filename, ss)
   result = parse_all(p)
   close_parser(p)
