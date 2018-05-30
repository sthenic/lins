import strutils


var quiet_mode = false


proc set_quiet_mode*(state: bool) =
   quiet_mode = state


template info*(msg: string, args: varargs[string]) =
   if not quiet_mode:
      echo format("\x1B[1;34mINFO:    \x1B[0m" & msg, args)


template warning*(msg: string, args: varargs[string]) =
   if not quiet_mode:
      echo format("\x1B[1;33mWARNING: \x1B[0m" & msg, args)


template error*(msg: string, args: varargs[string]) =
   if not quiet_mode:
      echo format("\x1B[1;31mERROR:   \x1B[0m" & msg, args)


template debug*(msg: string, args: varargs[string]) =
   when not defined(release):
      if not quiet_mode:
         echo format("\x1B[1;35mDEBUG:   \x1B[0m" & msg, args)


template abort*(e: typedesc[Exception], msg: string, args: varargs[string]) =
   error(msg, args)
   raise new_exception(e, format(msg, args))
