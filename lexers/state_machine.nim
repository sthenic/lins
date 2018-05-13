type
   State*[M, S] = ref object of RootObj
      id*: int
      name*: string
      is_final*: bool
      transitions*: seq[Transition[M, S]]

   Transition*[M, S] = ref object of RootObj
      condition_cb*: proc (meta: M, stimuli: S): bool
      transition_cb*: proc (meta: var M, stimuli: S)
      next_state*: State[M, S]

   StateMachine*[M, S] = ref object of RootObj
      init_state*: State[M, S]
      dead_state_cb*: proc (meta: var M, stimuli: S)
      current_state*: State[M, S]

proc reset*[M, S](this: StateMachine[M, S]) =
   this.current_state = this.init_state

proc run*[M, S](this: StateMachine[M, S], meta: var M, stimuli: S) =
   var do_transition = false

   if (this.current_state == nil):
      return

   for i in 0..<this.current_state.transitions.len:
      if not is_nil(this.current_state.transitions[i].condition_cb):
         do_transition = this.current_state.transitions[i].condition_cb(meta, stimuli)
      else:
         do_transition = true

      if do_transition:
         if not is_nil(this.current_state.transitions[i].transition_cb):
            this.current_state.transitions[i].transition_cb(meta, stimuli)
         this.current_state = this.current_state.transitions[i].next_state
         break

   if not do_transition:
      this.current_state = nil

   if (is_nil(this.current_state) and not is_nil(this.dead_state_cb)):
      this.dead_state_cb(meta, stimuli)

proc is_dead*[M, S](this: StateMachine[M, S]): bool =
   return is_nil(this.current_state)

proc is_final*[M, S](this: StateMachine[M, S]): bool =
   if is_nil(this.current_state):
      return false
   else:
      return this.current_state.is_final

