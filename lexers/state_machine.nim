type
   State*[T] = ref object of RootObj
      id*: int
      name*: string
      transitions*: seq[Transition[T]]

   Transition*[T] = ref object of RootObj
      condition_cb*: proc (c: T): bool
      transition_cb*: proc (c: T)
      next_state*: State[T]

   StateMachine*[T] = ref object of RootObj
      init_state*: State[T]
      dead_state_callback*: proc (c: T)
      current_state*: State[T]

proc reset*(sm: StateMachine) =
   sm.current_state = sm.init_state

proc run*[T](sm: StateMachine, stimuli: T) =
   var do_transition = false

   if (sm.current_state == nil):
      return

   for i in 0..<sm.current_state.transitions.len:
      if sm.current_state.transitions[i].condition_cb != nil:
         do_transition = sm.current_state.transitions[i].condition_cb(stimuli)
      else:
         do_transition = true

      if do_transition:
         if sm.current_state.transitions[i].transition_cb != nil:
            sm.current_state.transitions[i].transition_cb(stimuli)
         sm.current_state = sm.current_state.transitions[i].next_state
         break

   if not do_transition:
      sm.current_state = nil

   if (sm.current_state == nil and sm.dead_state_callback != nil):
      sm.dead_state_callback(stimuli)

proc is_dead*(sm: StateMachine): bool = return sm.current_state == nil
