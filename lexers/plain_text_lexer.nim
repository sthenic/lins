import unicode
import streams

import ./state_machine
import ../utils/log

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

# Forward declarations of conditions and transisiton callback functions.
proc is_letter(meta: PlainTextMeta, stimuli: Rune): bool
proc is_not_capital_letter(meta: PlainTextMeta, stimuli: Rune): bool
proc is_punctuation(meta: PlainTextMeta, stimuli: Rune): bool
proc is_space(meta: PlainTextMeta, stimuli: Rune): bool
proc is_newline(meta: PlainTextMeta, stimuli: Rune): bool
proc is_hyphen(meta: PlainTextMeta, stimuli: Rune): bool
proc is_ws(meta: PlainTextMeta, stimuli: Rune): bool
proc append(meta: var PlainTextMeta, stimuli: Rune)
proc append_first(meta: var PlainTextMeta, stimuli: Rune)
proc append_incr_nl(meta: var PlainTextMeta, stimuli: Rune)
proc insert_space(meta: var PlainTextMeta, stimuli: Rune)
proc prepend_space(meta: var PlainTextMeta, stimuli: Rune)
proc paragraph_complete(meta: var PlainTextMeta, stimuli: Rune)

# States
let
   STATE1 = PlainTextState(id: 1, name: "Init", is_final: false)
   STATE2 = PlainTextState(id: 2, name: "Append", is_final: true)
   STATE3 = PlainTextState(id: 3, name: "Punctuation", is_final: true)
   STATE4 = PlainTextState(id: 4, name: "SentenceComplete", is_final: false)
   STATE5 = PlainTextState(id: 5, name: "Space", is_final: false)
   STATE6 = PlainTextState(id: 6, name: "Newline", is_final: false)

# Transitions
let
   STATE1_TRANSITIONS = @[
      PlainTextTransition(condition_cb: is_letter, transition_cb: append_first,
                          next_state: STATE2),
      PlainTextTransition(condition_cb: is_ws, transition_cb: nil,
                          next_state: STATE1),
      PlainTextTransition(condition_cb: nil, transition_cb: nil,
                          next_state: STATE1)
   ]
   STATE2_TRANSITIONS = @[
      PlainTextTransition(condition_cb: is_letter, transition_cb: append,
                          next_state: STATE2),
      PlainTextTransition(condition_cb: is_punctuation, transition_cb: append,
                          next_state: STATE3),
      PlainTextTransition(condition_cb: is_space, transition_cb: append,
                          next_state: STATE5),
      PlainTextTransition(condition_cb: is_newline, transition_cb: insert_space,
                          next_state: STATE6)
   ]
   STATE3_TRANSITIONS = @[
      PlainTextTransition(condition_cb: is_letter, transition_cb: append,
                          next_state: STATE2),
      PlainTextTransition(condition_cb: is_punctuation, transition_cb: append,
                          next_state: STATE3),
      PlainTextTransition(condition_cb: is_ws, transition_cb: nil,
                          next_state: STATE4)
   ]
   STATE4_TRANSITIONS = @[
      PlainTextTransition(condition_cb: is_not_capital_letter,
                          transition_cb: prepend_space,
                          next_state: STATE2),
      PlainTextTransition(condition_cb: is_newline,
                          transition_cb: paragraph_complete,
                          next_state: nil)
   ]
   STATE5_TRANSITIONS = @[
      PlainTextTransition(condition_cb: is_letter, transition_cb: append,
                          next_state: STATE2),
      PlainTextTransition(condition_cb: is_space, transition_cb: nil,
                          next_state: STATE5),
      PlainTextTransition(condition_cb: is_newline, transition_cb: nil,
                          next_state: STATE6)
   ]
   STATE6_TRANSITIONS = @[
      PlainTextTransition(condition_cb: is_letter,
                          transition_cb: append_incr_nl,
                          next_state: STATE2),
      PlainTextTransition(condition_cb: is_space, transition_cb: nil,
                          next_state: STATE6),
      PlainTextTransition(condition_cb: is_newline,
                          transition_cb: paragraph_complete,
                          next_state: nil)
   ]

# Add transition sequences to the states.
STATE1.transitions = STATE1_TRANSITIONS
STATE2.transitions = STATE2_TRANSITIONS
STATE3.transitions = STATE3_TRANSITIONS
STATE4.transitions = STATE4_TRANSITIONS
STATE5.transitions = STATE5_TRANSITIONS
STATE6.transitions = STATE6_TRANSITIONS

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

proc append_incr_nl(meta: var PlainTextMeta, stimuli: Rune) =
   meta.sentence.newlines.add(meta.sentence.str.len)
   meta.sentence.str.add(stimuli)

proc insert_space(meta: var PlainTextMeta, stimuli: Rune) =
   meta.sentence.str.add(Rune(' '))

proc prepend_space(meta: var PlainTextMeta, stimuli: Rune) =
   meta.sentence.str.add(Rune(' '))
   meta.sentence.str.add(stimuli)

proc paragraph_complete(meta: var PlainTextMeta, stimuli: Rune) =
   meta.new_par = true

proc lex_file*(s: Stream, callback: proc (s: Sentence)) =
   var
      r: Rune
      pos_line: int = 0
      pos_last_line: int = 0
      pos_last_final: int = 0
      line: string = ""
      # Initialize a state machine for the plain-text syntax.
      sm: PlainTextStateMachine =
         PlainTextStateMachine(init_state: STATE1,
                               dead_state_cb: dead_state_callback)
      # Initialize a meta variable to represent the lexer's current state. This
      # variable is used pass around a mutable container between the state
      # machine's callback functions.
      meta: PlainTextMeta =
         (row: 1, col: 1, new_par: true, sentence_callback: callback,
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
               log.error("Failed to seek to position $#.", $pos_last_final)
               quit(-2)

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
         log.error("Failed to retrieve stream position, aborting.")
         quit(-2)

   if not is_dead(sm):
      dead_state_callback(meta, Rune(0))

   s.close()
