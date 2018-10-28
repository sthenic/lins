import unicode
import streams
import strutils

import ./state_machine
import ../utils/log

# TODO: Handle comments '%'

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
   Enclosure {.pure.} = enum
      Invalid
      Option
      Group
      Environment

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
      offset_pts: @[],
      par_idx: 0,
      row_begin: 0,
      col_begin: 0,
      row_end: 1,
      col_end: 1,
      scope: @[]
   )


proc new(t: typedesc[ScopeEntry]): ScopeEntry =
   (name: @[], kind: ScopeKind.Invalid, enclosure: Enclosure.Invalid)


proc new(t: typedesc[LaTeXMeta]): LaTeXMeta =
   (
      row: 0, col: 0,
      new_par: true,
      ws: @[],
      scope_entry: ScopeEntry.new(),
      scope: @[],
      sentence: Sentence.new(),
      sentence_stack: @[],
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


proc is_catcode_begin_group_cs_begin(meta: LaTeXMeta, stimuli: Rune): bool =
   return is_catcode_begin_group(meta, stimuli) and
          $meta.scope_entry.name == "begin"


proc is_catcode_begin_group_cs_end(meta: LaTeXMeta, stimuli: Rune): bool =
   return is_catcode_begin_group(meta, stimuli) and
          $meta.scope_entry.name == "end"


proc is_matched_catcode_end_group(meta: LaTeXMeta, stimuli: Rune): bool =
   return meta.scope != @[] and
          meta.scope[^1].enclosure == Enclosure.Group and
          stimuli in CATCODE_END_GROUP


proc is_matched_catcode_end_option(meta: LaTeXMeta, stimuli: Rune): bool =
   return meta.scope != @[] and
          meta.scope[^1].enclosure == Enclosure.Option and
          stimuli in CATCODE_END_OPTION


proc append(meta: var LaTeXMeta, stimuli: Rune) =
   meta.sentence.str.add(stimuli)
   meta.ws = @[]


proc append_scope(meta: var LaTeXMeta, stimuli: Rune) =
   meta.scope_entry.name.add(stimuli)


proc clear_scope(meta: var LaTeXMeta, stimuli: Rune) =
   # We insert an offset point to the current sentence whenever we clear scopes.
   var col = meta.col
   if meta.row == meta.sentence.row_end:
      col -= meta.sentence.col_end
   meta.sentence.offset_pts.add((meta.sentence.str.len,
                                 meta.row - meta.sentence.row_end,
                                 col))
   when defined(lexertrace):
      echo "Clearing scope entry '", meta.scope_entry, "'.\n"
   meta.scope_entry = ScopeEntry.new()


proc begin_enclosure(meta: var LaTeXMeta, stimuli: Rune) =
   # Push the current sentence object to the stack
   meta.sentence_stack.add(meta.sentence)
   when defined(lexertrace):
      echo "Pushing sentence", meta.sentence


   when defined(lexertrace):
      echo "Pushing scope entry sequence '", meta.scope_entry, "' to the stack."
   meta.scope.add(meta.scope_entry)

   # Initialize new sentence object w/ the current scope.
   meta.sentence = Sentence.new()
   meta.sentence.scope = meta.scope

   # TODO: This should be update from append first in INIT (do away w/ the + 1).
   meta.sentence.row_begin = meta.row
   meta.sentence.col_begin = meta.col + 1

   when defined(lexertrace):
      echo "Initializing new sentence: ", meta.sentence, "\n"

   meta.scope_entry = ScopeEntry.new()


proc end_enclosure(meta: var LaTeXMeta, stimuli: Rune) =
   # TODO: Emit current contents
   when defined(lexertrace):
      echo "Emitting sentence ", meta.sentence
      echo "row:  ", meta.row, " col: ", meta.col
   # Popping the stack
   meta.sentence = meta.sentence_stack.pop()
   when defined(lexertrace):
      echo "Popped sentence ", meta.sentence
   meta.scope_entry = meta.scope.pop()
   when defined(lexertrace):
      echo "Popped scope entry '", meta.scope_entry, "'\n"


proc begin_environment(meta: var LaTeXMeta, stimuli: Rune) =
   when defined(lexertrace):
      echo "Environment scope entry finished: '", $meta.scope_entry.name, "'."
   meta.scope_entry.kind = ScopeKind.Environment
   meta.scope_entry.enclosure = Enclosure.Environment
   begin_enclosure(meta, stimuli)


proc end_environment(meta: var LaTeXMeta, stimuli: Rune) =
   when defined(lexertrace):
      echo "Environment scope entry finished: '", $meta.scope_entry.name, "'."
   end_enclosure(meta, stimuli)


proc begin_group(meta: var LaTeXMeta, stimuli: Rune) =
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
   when defined(lexertrace):
      echo "Control sequence scope entry finished: '",
           $meta.scope_entry.name, "'."
   meta.scope_entry.kind = ScopeKind.ControlSequence


proc end_cs_begin_group(meta: var LaTeXMeta, stimuli: Rune) =
   end_cs(meta, stimuli)
   begin_group(meta, stimuli)


proc end_cs_begin_option(meta: var LaTeXMeta, stimuli: Rune) =
   end_cs(meta, stimuli)
   begin_option(meta, stimuli)


proc clear_scope_append(meta: var LaTeXMeta, stimuli: Rune) =
   when defined(lexertrace):
      echo "Clear append"
   clear_scope(meta, stimuli)
   append(meta, stimuli)


proc begin_cs(meta: var LaTeXMeta, stimuli: Rune) =
   meta.sentence.row_end = meta.row
   meta.sentence.col_end = meta.col


proc dead_state_callback(meta: var LaTeXMeta, stimuli: Rune) =
   when defined(lexertrace):
      echo "Emitting sentence ", meta.sentence
      echo "row:  ", meta.row, " col: ", meta.col
   # Reset
   meta.scope_entry = ScopeEntry.new()


# States
let
   S_INIT = LaTeXState.new(1, "Init", false)
   S_CS_ESCAPE = LaTeXState.new(2, "ControlSequenceEscape", false)
   S_CS_NAME = LaTeXState.new(3, "ControlSequenceName", false)
   S_CS_CHAR = LaTeXState.new(3, "ControlSequenceChar", false)
   S_CS_SPACE = LaTeXState.new(4, "ControlSequenceSpace", false)
   S_ENV_BEGIN = LaTeXState.new(5, "EnvironmentBegin", false)
   S_ENV_END = LaTeXState.new(6, "EnvironmentEnd", false)


# Transitions
let
   S_INIT_TRANSITIONS = @[
      LaTeXTransition.new(is_catcode_escape, begin_cs, S_CS_ESCAPE),
      LaTeXTransition.new(is_matched_catcode_end_group, end_group, S_CS_SPACE),
      LaTeXTransition.new(is_matched_catcode_end_option, end_option, S_CS_SPACE),
      LaTeXTransition.new(nil, append, S_INIT)
   ]
   S_CS_ESCAPE_TRANSITIONS = @[
      LaTeXTransition.new(is_catcode_letter, append_scope, S_CS_NAME),
      LaTeXTransition.new(is_ws, nil, S_INIT),
      LaTeXTransition.new(nil, append_scope, S_CS_CHAR)
   ]
   S_CS_NAME_TRANSITIONS = @[
      LaTeXTransition.new(is_catcode_letter, append_scope, S_CS_NAME),
      LaTeXTransition.new(is_catcode_begin_group_cs_begin, clear_scope, S_ENV_BEGIN),
      LaTeXTransition.new(is_catcode_begin_group_cs_end, clear_scope, S_ENV_END),
      LaTeXTransition.new(is_ws, end_cs, S_CS_SPACE),
      LaTeXTransition.new(is_catcode_begin_group, end_cs_begin_group, S_INIT),
      LaTeXTransition.new(is_catcode_begin_option, end_cs_begin_option, S_INIT),
      LaTeXTransition.new(is_catcode_escape, clear_scope, S_CS_ESCAPE),
      LaTeXTransition.new(is_matched_catcode_end_group, end_group, S_CS_SPACE),
      LaTeXTransition.new(is_matched_catcode_end_option, end_option, S_CS_SPACE),
      LaTeXTransition.new(nil, clear_scope_append, S_INIT)
   ]
   S_CS_CHAR_TRANSITIONS = @[
      LaTeXTransition.new(is_ws, end_cs, S_CS_SPACE),
      LaTeXTransition.new(is_catcode_begin_group, end_cs_begin_group, S_INIT),
      LaTeXTransition.new(is_catcode_begin_option, end_cs_begin_option, S_INIT),
      LaTeXTransition.new(is_catcode_escape, clear_scope, S_CS_ESCAPE),
      LaTeXTransition.new(nil, clear_scope_append, S_INIT)
   ]
   S_CS_SPACE_TRANSITIONS = @[
      LaTeXTransition.new(is_ws, nil, S_CS_SPACE),
      LaTeXTransition.new(is_catcode_begin_group_cs_begin, clear_scope, S_ENV_BEGIN),
      LaTeXTransition.new(is_catcode_begin_group_cs_end, clear_scope, S_ENV_END),
      LaTeXTransition.new(is_catcode_begin_group, begin_group, S_INIT),
      LaTeXTransition.new(is_catcode_begin_option, begin_option, S_INIT),
      LaTeXTransition.new(is_matched_catcode_end_group, end_group, S_CS_SPACE),
      LaTeXTransition.new(is_matched_catcode_end_option, end_option, S_CS_SPACE),
      LaTeXTransition.new(is_catcode_escape, clear_scope, S_CS_ESCAPE),
      LaTeXTransition.new(nil, clear_scope_append, S_INIT)
   ]
   S_ENV_BEGIN_TRANSITIONS = @[
      LaTeXTransition.new(is_catcode_letter, append_scope, S_ENV_BEGIN),
      LaTeXTransition.new(is_catcode_end_group, begin_environment, S_CS_SPACE),
      LaTeXTransition.new(nil, clear_scope_append, S_INIT)
   ]
   S_ENV_END_TRANSITIONS = @[
      LaTeXTransition.new(is_catcode_letter, append_scope, S_ENV_END),
      LaTeXTransition.new(is_catcode_end_group, end_environment, S_CS_SPACE),
      LaTeXTransition.new(nil, clear_scope_append, S_INIT)
   ]

# Add transition sequences to the states.
S_INIT.transitions = S_INIT_TRANSITIONS
S_CS_ESCAPE.transitions = S_CS_ESCAPE_TRANSITIONS
S_CS_NAME.transitions = S_CS_NAME_TRANSITIONS
S_CS_CHAR.transitions = S_CS_CHAR_TRANSITIONS
S_CS_SPACE.transitions = S_CS_SPACE_TRANSITIONS
S_ENV_BEGIN.transitions = S_ENV_BEGIN_TRANSITIONS
S_ENV_END.transitions = S_ENV_END_TRANSITIONS


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
