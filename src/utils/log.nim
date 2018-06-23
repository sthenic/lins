import strutils
import terminal
import macros

var quiet_mode = false


const
   INFO_COLOR = fgBlue
   WARNING_COLOR = fgYellow
   ERROR_COLOR = fgRed
   DEBUG_COLOR = fgMagenta


proc set_quiet_mode*(state: bool) =
   quiet_mode = state


macro call_styled_write_line(args: varargs[typed]): untyped =
   proc unpack_args(p: NimNode, n: NimNode) {.compiletime.} =
      for c in children(n):
         if c.kind == nnkHiddenStdConv:
            p.unpack_args(c[1])
         else:
            p.add(c)

   result = newCall(bindSym"styledWriteLine")
   result.add(bindSym"stdout")
   result.unpack_args(args)


template info*(args: varargs[typed]) =
   if not quiet_mode:
      call_styled_write_line(styleBright, INFO_COLOR, "INFO:    ",
                             resetStyle, args)


template info*(msg: string, args: varargs[string]) =
   if not quiet_mode:
      call_styled_write_line(styleBright, INFO_COLOR, "INFO:    ",
                             resetStyle, format(msg, args))


template warning*(args: varargs[typed]) =
   if not quiet_mode:
      call_styled_write_line(styleBright, WARNING_COLOR, "WARNING: ",
                             resetStyle, args)


template warning*(msg: string, args: varargs[string]) =
   if not quiet_mode:
      call_styled_write_line(styleBright, WARNING_COLOR, "WARNING: ",
                             resetStyle, format(msg, args))


template error*(args: varargs[typed]) =
   if not quiet_mode:
      call_styled_write_line(styleBright, ERROR_COLOR, "ERROR:   ",
                             resetStyle, args)


template error*(msg: string, args: varargs[string]) =
   if not quiet_mode:
      call_styled_write_line(styleBright, ERROR_COLOR, "ERROR:   ",
                             resetStyle, format(msg, args))


template debug*(args: varargs[typed]) =
   when not defined(release):
      if not quiet_mode:
         call_styled_write_line(styleBright, DEBUG_COLOR, "DEBUG:   ",
                                resetStyle, args)


template debug*(msg: string, args: varargs[string]) =
   when not defined(release):
      if not quiet_mode:
         call_styled_write_line(styleBright, DEBUG_COLOR, "DEBUG:   ",
                                resetStyle, format(msg, args))


template abort*(e: typedesc[Exception], msg: string, args: varargs[string]) =
   error(msg, args)
   raise new_exception(e, format(msg, args))
