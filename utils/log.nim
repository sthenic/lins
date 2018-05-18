import strutils

template info(msg: string, args: varargs[string]) =
   echo format("\x1B[1;34m INFO: \x1B[0m" & msg, args)

template warning(msg: string, args: varargs[string]) =
   echo format("\x1B[1;33m WARNING: \x1B[0m" & msg, args)

template error(msg: string, args: varargs[string]) =
   echo format("\x1B[1;31m ERROR: \x1B[0m" & msg, args)

template debug(msg: string, args: varargs[string]) =
   when not defined(release):
      echo format("\x1B[1;35m DEBUG: \x1B[0m" & msg, args)

