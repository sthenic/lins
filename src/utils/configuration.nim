import parsecfg
import streams
import os
import strutils

import ./log

type
   CfgState* = object
      rule_dirs*: seq[CfgRuleDir]
      styles*: seq[CfgStyle]

   CfgParser* = object
      filename: string
      parser: parsecfg.CfgParser
      event: CfgEvent
      state: CfgState

   CfgRuleDir* = object
      name*: string
      path*: string

   CfgStyle* = object
      name*: string
      is_default*: bool
      rules*: seq[CfgStyleRule]

   CfgStyleRule* = object
      name*: string
      exceptions*: seq[string]
      only*: seq[string]


   CfgParseError* = object of ValueError


template abort(p: CfgParser, msg: string, args: varargs[string, `$`]) =
   log.abort(CfgParseError, format("l.$1: ", p.parser.line_number) & msg, args)


template warning(p: CfgParser, msg: string, args: varargs[string, `$`]) =
   log.warning(format("l.$1: ", p.parser.line_number) & msg, args)


proc get_event(p: var CfgParser) =
   p.event = next(p.parser)


proc parse_rule_dirs_section(p: var CfgParser) =
   while true:
      get_event(p)
      if p.event.kind != cfgKeyValuePair:
         break

      if len(p.event.value) == 0:
         # The path is given without an explicit name.
         if len(p.event.key) == 0:
            warning(p, "Empty path given as rule directory in file '$1'.", p.filename)
            continue

         var (head, tail) = split_path(p.event.key)
         while len(tail) == 0 and len(head) != 0:
            (head, tail) = split_path(head)

         var path = strip(expand_tilde(p.event.key), false, true, {'/'})
         if not is_absolute(path):
            path = parent_dir(p.filename) / path

         log.debug("Inferred name '$1' for rule dir '$2'.", tail, path)
         add(p.state.rule_dirs, CfgRuleDir(name: tail, path: path))
      else:
         # The path is given with an explicit name.
         var path = expand_tilde(p.event.key)
         if not is_absolute(path):
            path = parent_dir(p.filename) / path

         log.debug("Adding rule directory '$1' with name '$2'.",p.event.value, p.event.key)
         add(p.state.rule_dirs, CfgRuleDir(name: p.event.key, path: p.event.value))


proc parse_except_section(p: var CfgParser) =
   while true:
      get_event(p)
      if p.event.kind != cfgKeyValuePair:
         break
      if len(p.event.value) > 0:
         warning(p, "Unexpected key/value pair, skipping.")
         continue

      log.debug("    Adding new exception '$1' to rule '$2'.",
                p.event.key, p.state.styles[^1].rules[^1].name)
      add(p.state.styles[^1].rules[^1].exceptions, p.event.key)


proc parse_only_section(p: var CfgParser) =
   while true:
      get_event(p)
      if p.event.kind != cfgKeyValuePair:
         break
      if len(p.event.value) > 0:
         warning(p, "Unexpected key/value pair, skipping.")
         continue

      log.debug("    Adding new only '$1' to rule '$2'.", p.event.key,
                p.state.styles[^1].rules[^1].name)
      add(p.state.styles[^1].rules[^1].only, p.event.key)


proc parse_rule(p: var CfgParser) =
   if p.event.kind != cfgKeyValuePair:
      abort(p, "Expected a key/value pair.")
   elif p.event.key != "rule":
      abort(p, "Expected key 'rule'.")

   log.debug("  Adding new style rule '$1'.", p.event.value)
   add(p.state.styles[^1].rules, CfgStyleRule(name: p.event.value))

   # Check for an optional 'Except' or 'Only' section (mutually exclusive).
   get_event(p)
   if p.event.kind == cfgSectionStart:
      if p.event.section == "Except":
         parse_except_section(p)
      elif p.event.section == "Only":
         parse_only_section(p)


proc parse_style_section(p: var CfgParser) =
   # The next event has to be a key/value pair with 'name' as the key.
   get_event(p)
   if p.event.kind != cfgKeyValuePair:
      abort(p, "Expected a key/value pair.")
   elif p.event.key != "name":
      abort(p, "Expected key 'name' as the first field in a section, got '$1'.", p.event.key)
   log.debug("Adding new style '$1'.", p.event.value)
   add(p.state.styles, CfgStyle(name: p.event.value))

   # Parse the optional 'default' key.
   get_event(p)
   if p.event.kind == cfgKeyValuePair and p.event.key == "default":
      log.debug("  Setting as default style.")
      if len(p.event.value) == 0 or to_lower_ascii(p.event.value) == "true":
         p.state.styles[^1].is_default = true
      elif to_lower_ascii(p.event.value) == "false":
         p.state.styles[^1].is_default = false
      else:
         warning(p, "Unsupported value given to the style key/value pair 'default', got '$1'.",
                 p.event.value)
      get_event(p)

   # At least one rule is expected per style section.
   parse_rule(p)


proc parse_section*(p: var CfgParser) =
   case p.event.section
   of "RuleDirs":
      parse_rule_dirs_section(p)
   of "Style":
      parse_style_section(p)
   else:
      abort(p, "Unexpected section '$1'.", p.event.section)


proc parse*(p: var CfgParser, s: Stream, filename: string): CfgState =
   open(p.parser, s, filename)
   while true:
      get_event(p)
      case p.event.kind
      of cfgEof:
         break
      of cfgSectionStart:
         parse_section(p)
      else:
         abort(p, "Unexpected file contents.")
   close(p.parser)
   result = p.state
