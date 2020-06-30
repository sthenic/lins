import parsecfg
import streams
import os
import strutils

import ./log

type
   CfgState* = object
      filename*: string
      rule_dirs*: seq[CfgRuleDir]
      styles*: seq[CfgStyle]

   CfgParser = object
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
      if p.event.kind != cfgKeyValuePair or len(p.event.value) > 0:
         break

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
      abort(p, "Expected a 'rule' key/value pair.")
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
   while true:
      parse_rule(p)
      if p.event.kind != cfgKeyValuePair or p.event.key != "rule":
         break


proc parse_section*(p: var CfgParser) =
   case p.event.section
   of "RuleDirs":
      parse_rule_dirs_section(p)
   of "Style":
      parse_style_section(p)
   else:
      abort(p, "Unexpected section '$1'.", p.event.section)


proc parse*(s: Stream, filename: string): CfgState =
   var p: CfgParser
   open(p.parser, s, filename)
   get_event(p)
   while true:
      case p.event.kind
      of cfgEof:
         break
      of cfgSectionStart:
         parse_section(p)
      else:
         abort(p, "Unexpected file contents.")
   close(p.parser)
   p.state.filename = filename
   result = p.state


proc get_configuration_file*(): string =
   ## Returns the full path to a configuration file, if one exists.
   const FILENAMES = @[".lins.cfg", "lins.cfg",
                       ".lins/.lins.cfg", ".lins/lins.cfg"]
   const FILENAMES_CFGDIR = @["lins/.lins.cfg", "lins/lins.cfg"]

   # Check for the environment variable 'LINS_CFG'. A valid configuration file
   # specified in this way takes precedence over the regular search.
   if exists_env("LINS_CFG"):
      let path = expand_tilde(get_env("LINS_CFG"))
      if file_exists(path):
         return path
      else:
         log.warning("Environment variable 'LINS_CFG' ('$1') does not " &
                     "specify an existing file.", path)

   # Walk from the current directory up to the root directory searching for a
   # configuraiton file.
   for path in parent_dirs(expand_filename("./"), false, true):
      for filename in FILENAMES:
         let tmp = path / filename
         if file_exists(tmp):
            return tmp

   # Default path to the user's configuration dir: ~/.config
   var path_to_cfgdir = get_home_dir() / ".config"
   when not defined(windows):
      # If 'XDG_CONFIG_HOME' is defined, we replace the default value.
      if exists_env("XDG_CONFIG_HOME"):
         path_to_cfgdir = expand_tilde(get_env("XDG_CONFIG_HOME"))

   for filename in FILENAMES_CFGDIR:
      let tmp = path_to_cfgdir / filename
      if file_exists(tmp):
         return tmp


proc get_default_style*(styles: seq[CfgStyle]): string =
   if exists_env("LINS_DEFAULT_STYLE"):
      let default_style_env = get_env("LINS_DEFAULT_STYLE")
      # Validate style
      for style in styles:
         if style.name == default_style_env:
            return default_style_env

      log.warning("Environment variable 'LINS_DEFAULT_STYLE' ('$1') does " &
                  "not match any defined style.", default_style_env)

   for style in styles:
      if style.is_default:
         if len(result) == 0:
            result = style.name
         else:
            log.warning("Only one style may be set as the default. " &
                        "Ignoring default specifier for style '$1'.",
                        style.name)
