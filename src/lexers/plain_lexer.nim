import unicode
import streams
import strutils

import ./state_machine
import ../utils/log

type PlainTextLexerFileIOError* = object of Exception

type
   Sentence* = tuple
      str: seq[Rune]
      newlines: seq[int]
      par_idx: int
      row_begin: int
      col_begin: int
      row_end: int
      col_end: int

   PlainTextMeta = tuple
      row, col: int
      new_par: bool
      sentence_callback: proc (s: Sentence)
      sentence: Sentence

   PlainTextState = State[PlainTextMeta, Rune]
   PlainTextTransition = Transition[PlainTextMeta, Rune]
   PlainTextStateMachine = StateMachine[PlainTextMeta, Rune]

const
   CAPITAL_LETTERS = toRunes("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
   PUNCTUATION = toRunes(".!?")
   SPACE = toRunes(" \t")
   NEWLINE = toRunes("\n\r")
   HYPHEN = toRunes("-")
   WHITESPACE = toRunes(" \t\n\r")
   ABBREVIATIONS = @[
      toRunes("Mr."),
      toRunes("Mrs."),
      toRunes("Ms."),
      toRunes("Mt."),
      toRunes("St."),
      toRunes("st.")
   ]

# Forward declarations of conditions and transisiton callback functions.
proc is_letter(meta: PlainTextMeta, stimuli: Rune): bool
proc is_not_capital_letter(meta: PlainTextMeta, stimuli: Rune): bool
proc is_punctuation(meta: PlainTextMeta, stimuli: Rune): bool
proc is_space(meta: PlainTextMeta, stimuli: Rune): bool
proc is_newline(meta: PlainTextMeta, stimuli: Rune): bool
proc is_hyphen(meta: PlainTextMeta, stimuli: Rune): bool
proc is_ws(meta: PlainTextMeta, stimuli: Rune): bool
proc is_abbreviation(meta: PlainTextMeta, stimuli: Rune): bool

proc append(meta: var PlainTextMeta, stimuli: Rune)
proc append_first(meta: var PlainTextMeta, stimuli: Rune)
proc insert_space(meta: var PlainTextMeta, stimuli: Rune)
proc prepend_space(meta: var PlainTextMeta, stimuli: Rune)
proc paragraph_complete(meta: var PlainTextMeta, stimuli: Rune)
proc prepend_space_incr_nl(meta: var PlainTextMeta, stimuli: Rune)

# States
let
   S_INIT =
      PlainTextState(id: 1, name: "Init", is_final: false)
   S_APPEND =
      PlainTextState(id: 2, name: "Append", is_final: true)
   S_PUNC =
      PlainTextState(id: 3, name: "Punctuation", is_final: true)
   S_SEN_DONE =
      PlainTextState(id: 4, name: "SentenceDone", is_final: false)
   S_SPACE =
      PlainTextState(id: 5, name: "Space", is_final: false)
   S_NEWLINE =
      PlainTextState(id: 6, name: "Newline", is_final: false)
   S_APPEND_FIRST =
      PlainTextState(id: 7, name: "AppendFirstLetter", is_final: true)
   S_NOBREAK_PUNC =
      PlainTextState(id: 8, name: "NoBreakPunctuation", is_final: true)

# Transitions
let
   S_INIT_TRANSITIONS = @[
      PlainTextTransition(condition_cb: is_letter, transition_cb: append_first,
                          next_state: S_APPEND_FIRST),
      PlainTextTransition(condition_cb: is_ws, transition_cb: nil,
                          next_state: S_INIT),
      PlainTextTransition(condition_cb: nil, transition_cb: nil,
                          next_state: S_INIT)
   ]
   S_APPEND_FIRST_TRANSITIONS = @[
      PlainTextTransition(condition_cb: is_letter, transition_cb: append,
                          next_state: S_APPEND),
      PlainTextTransition(condition_cb: is_punctuation, transition_cb: append,
                          next_state: S_NOBREAK_PUNC),
      PlainTextTransition(condition_cb: is_space, transition_cb: append,
                          next_state: S_SPACE),
      PlainTextTransition(condition_cb: is_newline, transition_cb: nil,
                          next_state: S_NEWLINE)
   ]
   S_NOBREAK_PUNC_TRANSITIONS = @[
      PlainTextTransition(condition_cb: is_letter, transition_cb: append,
                          next_state: S_APPEND_FIRST),
      PlainTextTransition(condition_cb: is_punctuation, transition_cb: append,
                          next_state: S_NOBREAK_PUNC),
      PlainTextTransition(condition_cb: is_space, transition_cb: append,
                          next_state: S_SPACE),
      PlainTextTransition(condition_cb: is_newline, transition_cb: nil,
                          next_state: S_NEWLINE)
   ]
   S_APPEND_TRANSITIONS = @[
      PlainTextTransition(condition_cb: is_letter, transition_cb: append,
                          next_state: S_APPEND),
      PlainTextTransition(condition_cb: is_abbreviation, transition_cb: append,
                          next_state: S_NOBREAK_PUNC),
      PlainTextTransition(condition_cb: is_punctuation, transition_cb: append,
                          next_state: S_PUNC),
      PlainTextTransition(condition_cb: is_space, transition_cb: append,
                          next_state: S_SPACE),
      PlainTextTransition(condition_cb: is_newline, transition_cb: nil,
                          next_state: S_NEWLINE)
   ]
   S_PUNC_TRANSITIONS = @[
      PlainTextTransition(condition_cb: is_letter, transition_cb: append,
                          next_state: S_APPEND),
      PlainTextTransition(condition_cb: is_punctuation, transition_cb: append,
                          next_state: S_PUNC),
      PlainTextTransition(condition_cb: is_ws, transition_cb: nil,
                          next_state: S_SEN_DONE)
   ]
   S_SEN_DONE_TRANSITIONS = @[
      PlainTextTransition(condition_cb: is_not_capital_letter,
                          transition_cb: prepend_space,
                          next_state: S_APPEND_FIRST),
      PlainTextTransition(condition_cb: is_newline,
                          transition_cb: paragraph_complete,
                          next_state: nil),
      PlainTextTransition(condition_cb: is_ws, transition_cb: insert_space,
                          next_state: S_SEN_DONE)
   ]
   S_SPACE_TRANSITIONS = @[
      PlainTextTransition(condition_cb: is_letter, transition_cb: append,
                          next_state: S_APPEND_FIRST),
      PlainTextTransition(condition_cb: is_space, transition_cb: nil,
                          next_state: S_SPACE),
      PlainTextTransition(condition_cb: is_newline, transition_cb: nil,
                          next_state: S_NEWLINE)
   ]
   S_NEWLINE_TRANSITIONS = @[
      PlainTextTransition(condition_cb: is_letter,
                          transition_cb: prepend_space_incr_nl,
                          next_state: S_APPEND_FIRST),
      PlainTextTransition(condition_cb: is_space, transition_cb: nil,
                          next_state: S_NEWLINE),
      PlainTextTransition(condition_cb: is_newline,
                          transition_cb: paragraph_complete,
                          next_state: nil)
   ]

# Add transition sequences to the states.
S_INIT.transitions = S_INIT_TRANSITIONS
S_APPEND.transitions = S_APPEND_TRANSITIONS
S_PUNC.transitions = S_PUNC_TRANSITIONS
S_SEN_DONE.transitions = S_SEN_DONE_TRANSITIONS
S_SPACE.transitions = S_SPACE_TRANSITIONS
S_NEWLINE.transitions = S_NEWLINE_TRANSITIONS
S_APPEND_FIRST.transitions = S_APPEND_FIRST_TRANSITIONS
S_NOBREAK_PUNC.transitions = S_NOBREAK_PUNC_TRANSITIONS

# Condition callbacks
proc is_letter(meta: PlainTextMeta, stimuli: Rune): bool =
   return stimuli notin PUNCTUATION and stimuli notin WHITESPACE

proc is_not_capital_letter(meta: PlainTextMeta, stimuli: Rune): bool =
   return is_letter(meta, stimuli) and stimuli notin CAPITAL_LETTERS

proc is_punctuation(meta: PlainTextMeta, stimuli: Rune): bool =
   return stimuli in PUNCTUATION

proc is_space(meta: PlainTextMeta, stimuli: Rune): bool =
   return stimuli in SPACE

proc is_newline(meta: PlainTextMeta, stimuli: Rune): bool =
   return stimuli in NEWLINE

proc is_hyphen(meta: PlainTextMeta, stimuli: Rune): bool =
   return stimuli in HYPHEN

proc is_ws(meta: PlainTextMeta, stimuli: Rune): bool =
   return stimuli in WHITESPACE

proc is_abbreviation(meta: PlainTextMeta, stimuli: Rune): bool =
   if not (stimuli in PUNCTUATION):
      return false

   for abr in ABBREVIATIONS:
      if ($meta.sentence.str & $stimuli).ends_with($abr):
         return true

proc dead_state_callback(meta: var PlainTextMeta, stimul: Rune) =
   # Invoke the callback function for a completed sentence.
   if not is_nil(meta.sentence_callback):
      meta.sentence_callback(meta.sentence)

   # Reset
   meta.sentence.str = @[]
   meta.sentence.newlines = @[]

# Transition callbacks
proc append(meta: var PlainTextMeta, stimuli: Rune) =
   meta.sentence.str.add(stimuli)

proc append_first(meta: var PlainTextMeta, stimuli: Rune) =
   meta.sentence.row_begin = meta.row
   meta.sentence.col_begin = meta.col

   if meta.new_par:
      meta.sentence.par_idx += 1
      meta.new_par = false

   meta.sentence.str.add(stimuli)

proc prepend_space_incr_nl(meta: var PlainTextMeta, stimuli: Rune) =
   meta.sentence.newlines.add(meta.sentence.str.len)
   prepend_space(meta, stimuli)

proc insert_space(meta: var PlainTextMeta, stimuli: Rune) =
   meta.sentence.str.add(Rune(' '))

proc prepend_space(meta: var PlainTextMeta, stimuli: Rune) =
   meta.sentence.str.add(Rune(' '))
   meta.sentence.str.add(stimuli)

proc paragraph_complete(meta: var PlainTextMeta, stimuli: Rune) =
   meta.new_par = true

proc lex*(s: Stream, callback: proc (s: Sentence), row_init, col_init: int) =
   var
      r: Rune
      pos_line: int = 0
      pos_last_line: int = 0
      pos_last_final: int = 0
      line: string = ""
      # Initialize a state machine for the plain-text syntax.
      sm: PlainTextStateMachine =
         PlainTextStateMachine(init_state: S_INIT,
                               dead_state_cb: dead_state_callback)
      # Initialize a meta variable to represent the lexer's current state. This
      # variable is used pass around a mutable container between the state
      # machine's callback functions.
      meta: PlainTextMeta =
         (row: row_init, col: col_init, new_par: true,
          sentence_callback: callback,
          sentence: (str: @[], newlines: @[], par_idx: 0, row_begin: 0,
                     col_begin: 0, row_end: 1, col_end: 1))

   # Reset the state machine.
   state_machine.reset(sm)

   while s.read_line(line):
      pos_line = 0
      line.add('\n') # Add the newline character removed by read_line().
      while pos_line < line.len:
         # Use the template provided by the unicode standard library to decode
         # the codepoint at position 'pos_line'. The rune is returned in r and
         # pos_line is automatically incremented with the number of bytes
         # consumed.
         fast_rune_at(line, pos_line, r, true)
         # Process stimuli
         state_machine.run(sm, meta, r)
         # Check resulting state
         if is_dead(sm):
            # Dead state reached, seek to last final position.
            try:
               s.set_position(pos_last_final)
            except IOError:
               log.abort(PlainTextLexerFileIOError,
                         "Failed to seek to position $#.", $pos_last_final)

            # Reset the state machine
            state_machine.reset(sm)
            # Reset positional counters
            meta.row = meta.sentence.row_end
            meta.col = meta.sentence.col_end + 1
            # Break to continue with the next input character (outer loop
            # re-reads the line from the correct position).
            break
         elif is_final(sm):
            pos_last_final = pos_last_line + pos_line
            meta.sentence.row_end = meta.row
            meta.sentence.col_end = meta.col

         if (r == Rune('\n')):
            meta.row += 1
            meta.col = 1
         else:
            meta.col += 1

      try:
         pos_last_line = s.get_position()
      except IOError:
         log.abort(PlainTextLexerFileIOError,
                   "Failed to retrieve stream position, aborting.")

   if not is_dead(sm):
      dead_state_callback(meta, Rune(0))

   s.close()
