import unicode
import streams
import strutils

import ./state_machine
import ../utils/log

type LaTeXLexerFileIOError* = object of Exception

type
   Enclosure {.pure.} = enum
      Invalid
      Option
      Group

   ScopeKind {.pure.} = enum
      Invalid
      ControlSequence
      Environment

   ScopeEntry = tuple
      name: seq[Rune]
      kind: ScopeKind
      enclosure: Enclosure

   Sentence* = tuple
      str: seq[Rune]
      offset_pts: seq[tuple[pos, row, col: int]]
      par_idx: int
      row_begin: int
      col_begin: int
      row_end: int
      col_end: int
      scope: seq[ScopeEntry]

   LaTeXMeta = tuple
      row, col: int
      new_par: bool
      ws: seq[Rune]
      scope_entry: ScopeEntry
      scope: seq[ScopeEntry]
      sentence: Sentence
      sentence_stack: seq[Sentence]
      sentence_callback: proc (s: Sentence)

   LaTeXState = State[LaTeXMeta, Rune]
   LaTeXTransition = Transition[LaTeXMeta, Rune]
   LaTeXStateMachine = StateMachine[LaTeXMeta, Rune]

# TODO: We need to add a common stack for both control sequences and
# environments to determine the nesting order. Should be a stack of a custom
# type.

const
   CATCODE_ESCAPE = toRunes("\\")
   CATCODE_BEGIN_GROUP = toRunes("{")
   CATCODE_END_GROUP = toRunes("}")
   CATCODE_BEGIN_OPTION = toRunes("[")
   CATCODE_END_OPTION = toRunes("]")
   CATCODE_LETTER =
      toRunes("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")
   WHITESPACE = toRunes(" \t\n\r")

# Forward declarations of conditions and transition callback functions.
proc is_catcode_escape(meta: LaTeXMeta, stimuli: Rune): bool
proc is_catcode_letter(meta: LaTeXMeta, stimuli: Rune): bool
proc is_ws_cs_begin(meta: LaTeXMeta, stimuli: Rune): bool
proc is_catcode_begin_group_cs_begin(meta: LaTeXMeta, stimuli: Rune): bool
proc is_catcode_begin_group(meta: LaTeXMeta, stimuli: Rune): bool
proc is_matched_catcode_end_group(meta: LaTeXMeta, stimuli: Rune): bool
proc is_catcode_begin_option(meta: LaTeXMeta, stimuli: Rune): bool
proc is_matched_catcode_end_option(meta: LaTeXMeta, stimuli: Rune): bool
proc is_ws(meta: LaTeXMeta, stimuli: Rune): bool
proc is_catcode_end_group(meta: LaTeXMeta, stimuli: Rune): bool
proc is_catcode_end_option(meta: LaTeXMeta, stimuli: Rune): bool

proc append(meta: var LaTeXMeta, stimuli: Rune)
proc append_scope(meta: var LaTeXMeta, stimuli: Rune)
proc end_cs(meta: var LaTeXMeta, stimuli: Rune)
proc begin_group(meta: var LaTeXMeta, stimuli: Rune)
proc end_group(meta: var LaTeXMeta, stimuli: Rune)
proc end_cs_begin_group(meta: var LaTeXMeta, stimuli: Rune)
proc begin_option(meta: var LaTeXMeta, stimuli: Rune)
proc end_option(meta: var LaTeXMeta, stimuli: Rune)
proc end_cs_begin_option(meta: var LaTeXMeta, stimuli: Rune)
proc begin_environment(meta: var LaTeXMeta, stimuli: Rune)
proc clear_scope(meta: var LaTeXMeta, stimuli: Rune)
proc clear_scope_append(meta: var LaTeXMeta, stimuli: Rune)


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
   S_ENV_NAME =
      LaTeXState(id: 5, name: "EnvironmentName", is_final: false)
   S_ENV_SPACE =
      LaTeXState(id: 5, name: "EnvironmentSpace", is_final: false)

# Transitions
let
   S_INIT_TRANSITIONS = @[
      LaTeXTransition(condition_cb: is_catcode_escape, transition_cb: nil,
                      next_state: S_CS_ESCAPE),
      LaTeXTransition(condition_cb: is_matched_catcode_end_group,
                      transition_cb: end_group,
                      next_state: S_CS_SPACE),
      LaTeXTransition(condition_cb: is_matched_catcode_end_option,
                      transition_cb: end_option,
                      next_state: S_CS_SPACE),
      LaTeXTransition(condition_cb: nil, transition_cb: append,
                      next_state: S_INIT)
   ]
   S_CS_ESCAPE_TRANSITIONS = @[
      LaTeXTransition(condition_cb: is_catcode_letter, transition_cb: append_scope,
                      next_state: S_CS_NAME),
      LaTeXTransition(condition_cb: is_ws, transition_cb: nil,
                      next_state: S_INIT),
      LaTeXTransition(condition_cb: nil, transition_cb: append_scope,
                      next_state: S_CS_CHAR)
   ]
   S_CS_NAME_TRANSITIONS = @[
      LaTeXTransition(condition_cb: is_catcode_letter, transition_cb: append_scope,
                      next_state: S_CS_NAME),
      LaTeXTransition(condition_cb: is_catcode_begin_group_cs_begin,
                      transition_cb: clear_scope,
                      next_state: S_ENV_NAME),
      LaTeXTransition(condition_cb: is_ws_cs_begin, transition_cb: clear_scope,
                      next_state: S_ENV_SPACE),
      LaTeXTransition(condition_cb: is_ws, transition_cb: end_cs,
                      next_state: S_CS_SPACE),
      LaTeXTransition(condition_cb: is_catcode_begin_group,
                      transition_cb: end_cs_begin_group,
                      next_state: S_INIT),
      LaTeXTransition(condition_cb: is_catcode_begin_option,
                      transition_cb: end_cs_begin_option,
                      next_state: S_INIT),
      LaTeXTransition(condition_cb: is_catcode_escape,
                      transition_cb: clear_scope,
                      next_state: S_CS_ESCAPE),
      LaTeXTransition(condition_cb: nil, transition_cb: clear_scope_append,
                      next_state: S_INIT)
   ]
   S_CS_CHAR_TRANSITIONS = @[
      LaTeXTransition(condition_cb: is_ws, transition_cb: end_cs,
                      next_state: S_CS_SPACE),
      LaTeXTransition(condition_cb: is_catcode_begin_group,
                      transition_cb: end_cs_begin_group,
                      next_state: S_INIT),
      LaTeXTransition(condition_cb: is_catcode_begin_option,
                      transition_cb: end_cs_begin_option,
                      next_state: S_INIT),
      LaTeXTransition(condition_cb: is_catcode_escape,
                      transition_cb: clear_scope,
                      next_state: S_CS_ESCAPE),
      LaTeXTransition(condition_cb: nil, transition_cb: clear_scope_append,
                      next_state: S_INIT)
   ]
   S_CS_SPACE_TRANSITIONS = @[
      LaTeXTransition(condition_cb: is_ws, transition_cb: nil,
                      next_state: S_CS_SPACE),
      LaTeXTransition(condition_cb: is_catcode_begin_group,
                      transition_cb: begin_group,
                      next_state: S_INIT),
      LaTeXTransition(condition_cb: is_catcode_begin_option,
                      transition_cb: begin_option,
                      next_state: S_INIT),
      LaTeXTransition(condition_cb: is_matched_catcode_end_group,
                      transition_cb: end_group,
                      next_state: S_CS_SPACE),
      LaTeXTransition(condition_cb: is_matched_catcode_end_option,
                      transition_cb: end_option,
                      next_state: S_CS_SPACE),
      LaTeXTransition(condition_cb: is_catcode_escape,
                      transition_cb: clear_scope,
                      next_state: S_CS_ESCAPE),
      LaTeXTransition(condition_cb: nil, transition_cb: clear_scope_append,
                      next_state: S_INIT)
   ]
   S_ENV_NAME_TRANSITIONS = @[
      LaTeXTransition(condition_cb: is_catcode_letter,
                      transition_cb: append_scope, next_state: S_ENV_NAME),
      LaTeXTransition(condition_cb: is_catcode_end_group,
                      transition_cb: begin_environment,
                      next_state: S_CS_SPACE),
      LaTeXTransition(condition_cb: nil, transition_cb: clear_scope_append,
                      next_state: S_INIT)
   ]
   S_ENV_SPACE_TRANSITIONS = @[
      LaTeXTransition(condition_cb: is_ws, transition_cb: nil,
                      next_state: S_ENV_SPACE),
      LaTeXTransition(condition_cb: is_catcode_begin_group,
                      transition_cb: nil,
                      next_state: S_ENV_NAME)
   ]

# Add transition sequences to the states.
S_INIT.transitions = S_INIT_TRANSITIONS
S_CS_ESCAPE.transitions = S_CS_ESCAPE_TRANSITIONS
S_CS_NAME.transitions = S_CS_NAME_TRANSITIONS
S_CS_CHAR.transitions = S_CS_CHAR_TRANSITIONS
S_CS_SPACE.transitions = S_CS_SPACE_TRANSITIONS
S_ENV_NAME.transitions = S_ENV_NAME_TRANSITIONS
S_ENV_SPACE.transitions = S_ENV_SPACE_TRANSITIONS

proc is_catcode_escape(meta: LaTeXMeta, stimuli: Rune): bool =
   return stimuli in CATCODE_ESCAPE

proc is_catcode_letter(meta: LaTeXMeta, stimuli: Rune): bool =
   return stimuli in CATCODE_LETTER

proc is_ws(meta: LaTeXMeta, stimuli: Rune): bool =
   return stimuli in WHITESPACE

proc is_ws_cs_begin(meta: LaTeXMeta, stimuli: Rune): bool =
   return is_ws(meta, stimuli) and $meta.scope_entry.name == "begin"

proc is_catcode_begin_group_cs_begin(meta: LaTeXMeta, stimuli: Rune): bool =
   return is_catcode_begin_group(meta, stimuli) and
          $meta.scope_entry.name == "begin"

proc is_catcode_begin_group(meta: LaTeXMeta, stimuli: Rune): bool =
   return stimuli in CATCODE_BEGIN_GROUP

proc is_catcode_end_group(meta: LaTeXMeta, stimuli: Rune): bool =
   return stimuli in CATCODE_END_GROUP

proc is_matched_catcode_end_group(meta: LaTeXMeta, stimuli: Rune): bool =
   return meta.scope != @[] and
          meta.scope[^1].enclosure == Enclosure.Group and
          stimuli in CATCODE_END_GROUP

proc is_catcode_begin_option(meta: LaTeXMeta, stimuli: Rune): bool =
   return stimuli in CATCODE_BEGIN_OPTION

proc is_catcode_end_option(meta: LaTeXMeta, stimuli: Rune): bool =
   return stimuli in CATCODE_END_OPTION

proc is_matched_catcode_end_option(meta: LaTeXMeta, stimuli: Rune): bool =
   return meta.scope != @[] and
          meta.scope[^1].enclosure == Enclosure.Option and
          stimuli in CATCODE_END_OPTION

proc append(meta: var LaTeXMeta, stimuli: Rune) =
   meta.sentence.str.add(stimuli)
   meta.ws = @[]

proc append_scope(meta: var LaTeXMeta, stimuli: Rune) =
   meta.scope_entry.name.add(stimuli)

proc end_cs_begin_group(meta: var LaTeXMeta, stimuli: Rune) =
   end_cs(meta, stimuli)
   begin_group(meta, stimuli)

proc end_cs_begin_option(meta: var LaTeXMeta, stimuli: Rune) =
   end_cs(meta, stimuli)
   begin_option(meta, stimuli)

proc begin_environment(meta: var LaTeXMeta, stimuli: Rune) =
   echo "Environment scope entry finished: '", $meta.scope_entry.name, "'."
   meta.scope_entry.kind = Environment

proc begin_enclosure(meta: var LaTeXMeta, stimuli: Rune) =
   # Push the current sentence object to the stack
   meta.sentence_stack.add(meta.sentence)
   echo "Pushing sentence", meta.sentence

   echo "Pushing scope entry sequence '", meta.scope_entry, "' to the stack."
   meta.scope.add(meta.scope_entry)

   # Initialize new empty sentence
   meta.sentence = (
      str: @[], offset_pts: @[], par_idx: 0, row_begin: 0, col_begin: 0,
      row_end: 1, col_end: 1, scope: meta.scope)
   echo "Initializing new sentence: ", meta.sentence, "\n"

   meta.scope_entry = (
      name: @[], kind: ScopeKind.Invalid, enclosure: Enclosure.Invalid)

proc end_enclosure(meta: var LaTeXMeta, stimuli: Rune) =
   # echo "Ending group on character '", $stimuli, "'"
   # Emit current contents
   echo "Emitting sentence ", meta.sentence
   # Popping the stack
   meta.sentence = meta.sentence_stack.pop()
   # echo "Popped sentence ", meta.sentence
   meta.scope_entry = meta.scope.pop()
   # echo "Popped scope entry '", meta.scope_entry, "'\n"

proc begin_group(meta: var LaTeXMeta, stimuli: Rune) =
   # echo "Beginning group on character '", $stimuli, "'", " w/ cseq '",
   #      $meta.scope_entry.name, "'"
   meta.scope_entry.enclosure = Enclosure.Group
   begin_enclosure(meta, stimuli)

proc end_group(meta: var LaTeXMeta, stimuli: Rune) =
   end_enclosure(meta, stimuli)

proc begin_option(meta: var LaTeXMeta, stimuli: Rune) =
   meta.scope_entry.enclosure = Enclosure.Option
   begin_enclosure(meta, stimuli)

proc end_option(meta: var LaTeXMeta, stimuli: Rune) =
   end_enclosure(meta, stimuli)

proc end_cs(meta: var LaTeXMeta, stimuli: Rune) =
   echo "Control sequence scope entry finished: '", $meta.scope_entry.name, "'."
   meta.scope_entry.kind = ScopeKind.ControlSequence

proc clear_scope_append(meta: var LaTeXMeta, stimuli: Rune) =
   echo "Clearappend"
   clear_scope(meta, stimuli)
   append(meta, stimuli)

proc clear_scope(meta: var LaTeXMeta, stimuli: Rune) =
   # echo "Clearing scope entry '", meta.scope_entry, "'.\n"
   meta.scope_entry = (
      name: @[], kind: ScopeKind.Invalid, enclosure: Enclosure.Invalid)

proc dead_state_callback(meta: var LaTeXMeta, stimuli: Rune) =
   echo "Reached the dead state on input '", $stimuli, "'"

   # Reset
   meta.scope_entry = (
      name: @[], kind: ScopeKind.Invalid, enclosure: Enclosure.Invalid)

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
         (row: row_init, col: col_init, new_par: true, ws: @[],
          scope_entry: (name: @[],
                        kind: ScopeKind.Invalid,
                        enclosure: Enclosure.Invalid),
          scope: @[],
          sentence: (str: @[], offset_pts: @[], par_idx: 0, row_begin: 0,
                     col_begin: 0, row_end: 1, col_end: 1, scope: @[]),
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
