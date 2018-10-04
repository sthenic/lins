import unicode
import streams
import strutils

import ./state_machine
import ../utils/log

type LaTeXLexerFileIOError* = object of Exception

type
   Sentence* = tuple
      str: seq[Rune]
      offset_pts: seq[tuple[pos, row, col: int]]
      par_idx: int
      row_begin: int
      col_begin: int
      row_end: int
      col_end: int
      cs_stack: seq[seq[Rune]]
      env_stack: seq[seq[Rune]]

   LaTeXMeta = tuple
      row, col: int
      new_par: bool
      ws: seq[Rune]
      in_group: bool
      cs_name: seq[Rune]
      cs_name_stack: seq[seq[Rune]]
      sentence: Sentence
      sentence_stack: seq[Sentence]
      sentence_callback: proc (s: Sentence)

   LaTeXState = State[LaTeXMeta, Rune]
   LaTeXTransition = Transition[LaTeXMeta, Rune]
   LaTeXStateMachine = StateMachine[LaTeXMeta, Rune]


const
   CATCODE_ESCAPE = toRunes("\\")
   CATCODE_BEGIN_GROUP = toRunes("{")
   CATCODE_END_GROUP = toRunes("}")
   CATCODE_LETTER =
      toRunes("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")
   WHITESPACE = toRunes(" \t\n\r")


# Forward declarations of conditions and transition callback functions.
proc is_catcode_escape(meta: LaTeXMeta, stimuli: Rune): bool
proc is_catcode_letter(meta: LaTeXMeta, stimuli: Rune): bool
proc is_catcode_begin_group(meta: LaTeXMeta, stimuli: Rune): bool
proc is_catcode_end_group(meta: LaTeXMeta, stimuli: Rune): bool
proc is_ws(meta: LaTeXMeta, stimuli: Rune): bool

proc append(meta: var LaTeXMeta, stimuli: Rune)
proc append_cs(meta: var LaTeXMeta, stimuli: Rune)
proc end_cs(meta: var LaTeXMeta, stimuli: Rune)
proc begin_group(meta: var LaTeXMeta, stimuli: Rune)
proc end_group(meta: var LaTeXMeta, stimuli: Rune)
proc end_cs_begin_group(meta: var LaTeXMeta, stimuli: Rune)
proc clear_cs(meta: var LaTeXMeta, stimuli: Rune)
proc clear_cs_append(meta: var LaTeXMeta, stimuli: Rune)

# States
let
   S_INIT =
      LaTeXState(id: 1, name: "Init", is_final: false)
   S_CS_ESCAPE =
      LaTeXState(id: 2, name: "ControlSequenceEscape", is_final: false)
   S_CS_NAME =
      LaTeXState(id: 3, name: "ControlSequenceName", is_final: true)
   S_CS_CHAR =
      LaTeXState(id: 3, name: "ControlSequenceChar", is_final: true)
   S_CS_SPACE =
      LaTeXState(id: 4, name: "ControlSequenceSpace", is_final: false)


# Transitions
let
   S_INIT_TRANSITIONS = @[
      LaTeXTransition(condition_cb: is_catcode_escape, transition_cb: nil,
                      next_state: S_CS_ESCAPE),
      LaTeXTransition(condition_cb: is_catcode_end_group,
                      transition_cb: end_group,
                      next_state: S_CS_SPACE), #S_GROUP_ENDED
      LaTeXTransition(condition_cb: nil, transition_cb: append,
                      next_state: S_INIT)
   ]
   S_CS_ESCAPE_TRANSITIONS = @[
      LaTeXTransition(condition_cb: is_catcode_letter, transition_cb: append_cs,
                      next_state: S_CS_NAME),
      LaTeXTransition(condition_cb: is_ws, transition_cb: nil,
                      next_state: S_INIT),
      LaTeXTransition(condition_cb: nil, transition_cb: append_cs,
                      next_state: S_CS_CHAR)
   ]
   S_CS_NAME_TRANSITIONS = @[
      LaTeXTransition(condition_cb: is_catcode_letter, transition_cb: append_cs,
                      next_state: S_CS_NAME),
      LaTeXTransition(condition_cb: is_ws, transition_cb: end_cs,
                      next_state: S_CS_SPACE),
      LaTeXTransition(condition_cb: is_catcode_begin_group,
                      transition_cb: end_cs_begin_group,
                      next_state: S_INIT),
      LaTeXTransition(condition_cb: is_catcode_escape,
                      transition_cb: clear_cs,
                      next_state: S_CS_ESCAPE),
      LaTeXTransition(condition_cb: nil, transition_cb: clear_cs,
                      next_state: S_INIT)
   ]
   S_CS_CHAR_TRANSITIONS = @[
      LaTeXTransition(condition_cb: is_ws, transition_cb: end_cs,
                      next_state: S_CS_SPACE),
      LaTeXTransition(condition_cb: is_catcode_begin_group,
                      transition_cb: end_cs_begin_group,
                      next_state: S_INIT),
      LaTeXTransition(condition_cb: is_catcode_escape,
                      transition_cb: clear_cs,
                      next_state: S_CS_ESCAPE),
      LaTeXTransition(condition_cb: nil, transition_cb: clear_cs,
                      next_state: S_INIT)
   ]
   S_CS_SPACE_TRANSITIONS = @[
      LaTeXTransition(condition_cb: is_ws, transition_cb: nil,
                      next_state: S_CS_SPACE),
      LaTeXTransition(condition_cb: is_catcode_begin_group,
                      transition_cb: begin_group,
                      next_state: S_INIT),
      LaTeXTransition(condition_cb: is_catcode_escape,
                      transition_cb: clear_cs,
                      next_state: S_CS_ESCAPE),
      LaTeXTransition(condition_cb: nil, transition_cb: clear_cs_append,
                      next_state: S_INIT)
   ]
   S_GROUP_ENDED_TRANSITIONS = @[
      LaTeXTransition(condition_cb: is_catcode_begin_group,
                      transition_cb: begin_group,
                      next_state: S_INIT),
      LaTeXTransition(condition_cb: nil, transition_cb: clear_cs,
                      next_state: S_INIT)
   ]


# Add transition sequences to the states.
S_INIT.transitions = S_INIT_TRANSITIONS
S_CS_ESCAPE.transitions = S_CS_ESCAPE_TRANSITIONS
S_CS_NAME.transitions = S_CS_NAME_TRANSITIONS
S_CS_CHAR.transitions = S_CS_CHAR_TRANSITIONS
S_CS_SPACE.transitions = S_CS_SPACE_TRANSITIONS


proc is_catcode_escape(meta: LaTeXMeta, stimuli: Rune): bool =
   return stimuli in CATCODE_ESCAPE


proc is_catcode_letter(meta: LaTeXMeta, stimuli: Rune): bool =
   return stimuli in CATCODE_LETTER


proc is_ws(meta: LaTeXMeta, stimuli: Rune): bool =
   return stimuli in WHITESPACE


proc is_catcode_begin_group(meta: LaTeXMeta, stimuli: Rune): bool =
   return stimuli in CATCODE_BEGIN_GROUP


proc is_catcode_end_group(meta: LaTeXMeta, stimuli: Rune): bool =
   return meta.in_group and stimuli in CATCODE_END_GROUP


proc append(meta: var LaTeXMeta, stimuli: Rune) =
   meta.sentence.str.add(stimuli)
   meta.ws = @[]


proc append_cs(meta: var LaTeXMeta, stimuli: Rune) =
   meta.cs_name.add(stimuli)


proc end_cs_begin_group(meta: var LaTeXMeta, stimuli: Rune) =
   end_cs(meta, stimuli)
   begin_group(meta, stimuli)


proc begin_group(meta: var LaTeXMeta, stimuli: Rune) =
   echo "Beginning group on character '", $stimuli, "'", " w/ cseq '",
        $meta.cs_name, "'"
   # Push the current sentence object to the stack
   meta.sentence_stack.add(meta.sentence)
   echo "Pushing ", meta.sentence
   # Initialize new empty sentence
   var tmp = meta.sentence.cs_stack
   tmp.add(meta.cs_name)
   meta.sentence = (
      str: @[], offset_pts: @[], par_idx: 0, row_begin: 0, col_begin: 0,
      row_end: 1, col_end: 1, cs_stack: tmp, env_stack: @[])
   echo "Adding new sentence: ", meta.sentence
   echo "Pushing control sequence '", $meta.cs_name, "' to the stack.\n"
   meta.cs_name_stack.add(meta.cs_name)
   meta.cs_name = @[]
   meta.in_group = true


proc end_group(meta: var LaTeXMeta, stimuli: Rune) =
   echo "Ending group on character '", $stimuli, "'"
   # Emit current contents
   echo "Emitting sentence ", meta.sentence
   # Popping the stack
   meta.sentence = meta.sentence_stack.pop()
   echo "Popped sentence ", meta.sentence
   meta.cs_name = meta.cs_name_stack.pop()
   echo "Popped control sequence '", $meta.cs_name, "'\n"
   meta.in_group = false


proc end_cs(meta: var LaTeXMeta, stimuli: Rune) =
   echo "Control sequence finished: '", $meta.cs_name, "'."


proc clear_cs_append(meta: var LaTeXMeta, stimuli: Rune) =
   clear_cs(meta, stimuli)
   append(meta, stimuli)


proc clear_cs(meta: var LaTeXMeta, stimuli: Rune) =
   echo "Clearing control sequence '", $meta.cs_name, "'.\n"
   meta.cs_name = @[]


proc dead_state_callback(meta: var LaTeXMeta, stimuli: Rune) =
   echo "Reached the dead state on input '", $stimuli, "'"

   # Reset
   meta.cs_name = @[]


proc lex*(s: Stream, callback: proc (s: Sentence), row_init, col_init: int) =
   var
      r: Rune
      pos_line: int = 0
      pos_last_line: int = 0
      pos_last_final: int = 0
      line: string = ""
      # Initialize a state machine for the plain-text syntax.
      sm: LaTeXStateMachine =
         LaTeXStateMachine(init_state: S_INIT,
                           dead_state_cb: dead_state_callback)
      # Initialize a meta variable to represent the lexer's current state. This
      # variable is used pass around a mutable container between the state
      # machine's callback functions.
      meta: LaTeXMeta =
         (row: row_init, col: col_init, new_par: true, ws: @[], in_group: false,
          cs_name: @[], cs_name_stack: @[],
          sentence: (str: @[], offset_pts: @[], par_idx: 0, row_begin: 0,
                     col_begin: 0, row_end: 1, col_end: 1, cs_stack: @[],
                     env_stack: @[]),
          sentence_stack: @[], sentence_callback: callback)

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

            # Reset the state machine
            echo "Resetting"
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
