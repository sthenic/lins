type
   ParseError* = object of Exception

   Linebreak* = tuple
      pos, line: int

   TextSegment* = object of RootObj
      text*: string
      line*, col*: int
      linebreaks*: seq[Linebreak]
