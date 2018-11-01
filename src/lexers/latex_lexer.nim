import unicode
import streams
import strutils

import ./state_machine
import ../utils/log


type LaTeXLexerFileIOError* = object of Exception


const
   CATCODE_ESCAPE = toRunes("\\")
   CATCODE_BEGIN_GROUP = toRunes("{")
   CATCODE_END_GROUP = toRunes("}")
   CATCODE_BEGIN_OPTION = toRunes("[")
   CATCODE_END_OPTION = toRunes("]")
   CATCODE_LETTER =
      toRunes("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")
   WHITESPACE = toRunes(" \t\n\r")


type
   Sentence* = tuple
      str: seq[Rune]
      row_begin: int
      col_begin: int
      row_end: int
      col_end: int

   LaTeXMeta = tuple
      row, col: int
      sentence: Sentence
      sentence_callback: proc (s: Sentence)

   LaTeXState = State[LaTeXMeta, Rune]
   LaTeXTransition = Transition[LaTeXMeta, Rune]
   LaTeXStateMachine = StateMachine[LaTeXMeta, Rune]


proc new(t: typedesc[LaTeXState], id: int, name: string,
         is_final: bool): LaTeXState =
   result = LaTeXState(id: id, name: name, is_final: is_final)


proc new(t: typedesc[LaTeXTransition],
         condition_cb: proc (m: LaTeXMeta, s: Rune): bool,
         transition_cb: proc (m: var LaTeXMeta, s: Rune),
         next_state: LaTeXState): LaTeXTransition =
   result = LaTeXTransition(
      condition_cb: condition_cb,
      transition_cb: transition_cb,
      next_state: next_state
   )


proc new(t: typedesc[Sentence]): Sentence =
   (
      str: @[],
      row_begin: 0,
      col_begin: 0,
      row_end: 1,
      col_end: 1,
   )


proc new(t: typedesc[LaTeXMeta]): LaTeXMeta =
   (
      row: 0, col: 0,
      sentence: Sentence.new(),
      sentence_callback: nil
   )


proc is_catcode_escape(meta: LaTeXMeta, stimuli: Rune): bool =
   return stimuli in CATCODE_ESCAPE


proc is_catcode_letter(meta: LaTeXMeta, stimuli: Rune): bool =
   return stimuli in CATCODE_LETTER


proc is_catcode_begin_group(meta: LaTeXMeta, stimuli: Rune): bool =
   return stimuli in CATCODE_BEGIN_GROUP


proc is_catcode_end_group(meta: LaTeXMeta, stimuli: Rune): bool =
   return stimuli in CATCODE_END_GROUP


proc is_catcode_begin_option(meta: LaTeXMeta, stimuli: Rune): bool =
   return stimuli in CATCODE_BEGIN_OPTION


proc is_catcode_end_option(meta: LaTeXMeta, stimuli: Rune): bool =
   return stimuli in CATCODE_END_OPTION


proc is_ws(meta: LaTeXMeta, stimuli: Rune): bool =
   return stimuli in WHITESPACE


proc dead_state_callback(meta: var LaTeXMeta, stimuli: Rune) =
   echo "Emitting sentence ", meta.sentence

   # Reset
   meta.sentence.str = @[]


# States according to p.46 of the TeXbook.
let
   S_N = LaTeXState.new(1, "BeginningOfLine", false)
   S_M = LaTeXState.new(1, "BeginningOfLine", false)
   S_S = LaTeXState.new(1, "BeginningOfLine", false)

# Transitions
let
   S_N_TRANSITIONS = @[
      LaTeXTransition.new(nil, nil, S_N)
   ]
   S_M_TRANSITIONS = @[
      LaTeXTransition.new(nil, nil, S_M)
   ]
   S_S_TRANSITIONS = @[
      LaTeXTransition.new(nil, nil, S_S)
   ]


# Add transition sequences to the states.
S_N.transitions = S_N_TRANSITIONS
S_M.transitions = S_M_TRANSITIONS
S_S.transitions = S_S_TRANSITIONS


proc lex*(s: Stream, callback: proc (s: Sentence), row_init, col_init: int) =
   var
      r: Rune
      pos_line: int = 0
      pos_last_line: int = 0
      pos_last_final: int = 0
      line: string = ""
      # Initialize a state machine for the plain-text syntax.
      sm: LaTeXStateMachine =
         LaTeXStateMachine(init_state: S_N,
                           dead_state_cb: dead_state_callback)
      # Initialize a meta variable to represent the lexer's current state. This
      # variable is used pass around a mutable container between the state
      # machine's callback functions.
      meta: LaTeXMeta = LaTeXMeta.new()

   # Overwrite some of the initial values of the meta object.
   meta.row = row_init
   meta.col = col_init
   meta.sentence_callback = callback

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
               log.abort(LaTeXLexerFileIOError,
                         "Failed to seek to position $1.", $pos_last_final)

            # Reset the state machin
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
         log.abort(LaTeXLexerFileIOError,
                   "Failed to retrieve stream position, aborting.")

   if not is_dead(sm):
      dead_state_callback(meta, Rune(0))

   s.close()
