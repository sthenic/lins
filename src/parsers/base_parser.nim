type
   ParseError* = object of Exception

   Linebreak* = tuple
      pos, line: int

   TextSegment* = object
      text*: string
      line*, col*: int
      linebreaks*: seq[Linebreak]


proc init*(seg: var TextSegment) =
   seg.line = 0
   seg.col = 0
   set_len(seg.text, 0)
   set_len(seg.linebreaks, 0)
