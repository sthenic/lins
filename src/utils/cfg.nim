import os
import ospaths
import parsecfg
import strutils
import streams

import ./log
import ../lexers/state_machine

type
   ConfigurationFileNotFoundError* = object of Exception
   ConfigurationPathError* = object of Exception
   ConfigurationParseError* = object of Exception

type
   Configuration* = object of RootObj
      filename*: string
      dir*: string
      rule_dirs*: seq[RuleDir]
      styles*: seq[Style]

   RuleDir* = object of RootObj
      name*: string
      path*: string

   Style* = object of RootObj
      name*: string
      is_default*: bool
      rules*: seq[StyleRule]

   StyleRule* = object of RootObj
      name*: string
      exceptions*: seq[string]
      only*: seq[string]

   ConfigurationState = State[Configuration, CfgEvent]
   ConfigurationTransition = Transition[Configuration, CfgEvent]
   ConfigurationStateMachine = StateMachine[Configuration, CfgEvent]


proc new(t: typedesc[Configuration], filename, dir: string):
      Configuration =
   result = Configuration(filename: filename, dir: dir,
                          rule_dirs: @[], styles: @[])


proc new(t: typedesc[RuleDir], name, path: string): RuleDir =
   result = RuleDir(name: name, path: path)


proc new(t: typedesc[Style], name: string): Style =
   result = Style(name: name, is_default: false, rules: @[])


proc new(t: typedesc[StyleRule], name: string): StyleRule =
   result = StyleRule(name: name, exceptions: @[], only: @[])


proc is_section_ruledirs(meta: Configuration, stimuli: CfgEvent): bool
proc is_section_style(meta: Configuration, stimuli: CfgEvent): bool
proc is_section_except(meta: Configuration, stimuli: CfgEvent): bool
proc is_section_only(meta: Configuration, stimuli: CfgEvent): bool
proc is_keyval(meta: Configuration, stimuli: CfgEvent): bool
proc is_keyval_name(meta: Configuration, stimuli: CfgEvent): bool
proc is_keyval_rule(meta: Configuration, stimuli: CfgEvent): bool
proc is_keyval_default(meta: Configuration, stimuli: CfgEvent): bool

proc add_rule_dir(meta: var Configuration, stimuli: CfgEvent)
proc add_style(meta: var Configuration, stimuli: CfgEvent)
proc set_style_default(meta: var Configuration, stimuli: CfgEvent)
proc add_style_rule(meta: var Configuration, stimuli: CfgEvent)
proc add_exception(meta: var Configuration, stimuli: CfgEvent)
proc add_only(meta: var Configuration, stimuli: CfgEvent)

let
   STATE1 = ConfigurationState(id: 1, name: "Init", is_final: false)
   STATE2 = ConfigurationState(id: 2, name: "SecRuleDirs", is_final: false)
   STATE3 = ConfigurationState(id: 3, name: "AddRuleDir", is_final: false)
   STATE4 = ConfigurationState(id: 4, name: "SecStyle", is_final: false)
   STATE5 = ConfigurationState(id: 5, name: "AddStyle", is_final: false)
   STATE6 = ConfigurationState(id: 6, name: "AddStyleRule", is_final: false)
   STATE7 = ConfigurationState(id: 7, name: "SecExcept", is_final: false)
   STATE8 = ConfigurationState(id: 8, name: "SecOnly", is_final: false)
   STATE9 = ConfigurationState(id: 9, name: "AddException", is_final: false)
   STATE10 = ConfigurationState(id: 10, name: "AddOnly", is_final: false)
   STATE11 = ConfigurationState(id: 11, name: "SetDefault", is_final: false)


let
   STATE1_TRANSITIONS = @[
      ConfigurationTransition(condition_cb: is_section_ruledirs,
                              transition_cb: nil,
                              next_state: STATE2),
      ConfigurationTransition(condition_cb: is_section_style,
                              transition_cb: nil,
                              next_state: STATE4)
   ]
   STATE2_TRANSITIONS = @[
      ConfigurationTransition(condition_cb: is_keyval,
                              transition_cb: add_rule_dir,
                              next_state: STATE3)
   ]
   STATE3_TRANSITIONS = @[
      ConfigurationTransition(condition_cb: is_keyval,
                              transition_cb: add_rule_dir,
                              next_state: STATE3),
      ConfigurationTransition(condition_cb: is_section_style,
                              transition_cb: nil,
                              next_state: STATE4)
   ]
   STATE4_TRANSITIONS = @[
      ConfigurationTransition(condition_cb: is_keyval_name,
                              transition_cb: add_style,
                              next_state: STATE5)
   ]
   STATE5_TRANSITIONS = @[
      ConfigurationTransition(condition_cb: is_keyval_rule,
                              transition_cb: add_style_rule,
                              next_state: STATE6),
      ConfigurationTransition(condition_cb: is_keyval_default,
                              transition_cb: set_style_default,
                              next_state: STATE11)
   ]
   STATE6_TRANSITIONS = @[
      ConfigurationTransition(condition_cb: is_keyval_rule,
                              transition_cb: add_style_rule,
                              next_state: STATE6),
      ConfigurationTransition(condition_cb: is_keyval_default,
                              transition_cb: set_style_default,
                              next_state: STATE11),
      ConfigurationTransition(condition_cb: is_section_except,
                              transition_cb: nil,
                              next_state: STATE7),
      ConfigurationTransition(condition_cb: is_section_only,
                              transition_cb: nil,
                              next_state: STATE8),
      ConfigurationTransition(condition_cb: is_section_style,
                              transition_cb: nil,
                              next_state: STATE4)
   ]
   STATE7_TRANSITIONS = @[
      ConfigurationTransition(condition_cb: is_keyval,
                              transition_cb: add_exception,
                              next_state: STATE9)
   ]
   STATE8_TRANSITIONS = @[
      ConfigurationTransition(condition_cb: is_keyval,
                              transition_cb: add_only,
                              next_state: STATE10)
   ]
   STATE9_TRANSITIONS = @[
      ConfigurationTransition(condition_cb: is_keyval_rule,
                              transition_cb: add_style_rule,
                              next_state: STATE6),
      ConfigurationTransition(condition_cb: is_keyval,
                              transition_cb: add_exception,
                              next_state: STATE9),
      ConfigurationTransition(condition_cb: is_section_style,
                              transition_cb: nil,
                              next_state: STATE4)
   ]
   STATE10_TRANSITIONS = @[
      ConfigurationTransition(condition_cb: is_keyval_rule,
                              transition_cb: add_style_rule,
                              next_state: STATE6),
      ConfigurationTransition(condition_cb: is_keyval,
                              transition_cb: add_only,
                              next_state: STATE10),
      ConfigurationTransition(condition_cb: is_section_style,
                              transition_cb: nil,
                              next_state: STATE4)
   ]
   STATE11_TRANSITIONS = @[
      ConfigurationTransition(condition_cb: is_keyval_rule,
                              transition_cb: add_style_rule,
                              next_state: STATE6)
   ]


STATE1.transitions = STATE1_TRANSITIONS
STATE2.transitions = STATE2_TRANSITIONS
STATE3.transitions = STATE3_TRANSITIONS
STATE4.transitions = STATE4_TRANSITIONS
STATE5.transitions = STATE5_TRANSITIONS
STATE6.transitions = STATE6_TRANSITIONS
STATE7.transitions = STATE7_TRANSITIONS
STATE8.transitions = STATE8_TRANSITIONS
STATE9.transitions = STATE9_TRANSITIONS
STATE10.transitions = STATE10_TRANSITIONS
STATE11.transitions = STATE11_TRANSITIONS


proc is_section_ruledirs(meta: Configuration, stimuli: CfgEvent): bool =
   result = (stimuli.kind == cfgSectionStart) and
            (stimuli.section == "RuleDirs")


proc is_section_style(meta: Configuration, stimuli: CfgEvent): bool =
   result = (stimuli.kind == cfgSectionStart) and
            (stimuli.section == "Style")


proc is_section_except(meta: Configuration, stimuli: CfgEvent): bool =
   result = (stimuli.kind == cfgSectionStart) and
            (stimuli.section == "Except")


proc is_section_only(meta: Configuration, stimuli: CfgEvent): bool =
   result = (stimuli.kind == cfgSectionStart) and
            (stimuli.section == "Only")


proc is_keyval(meta: Configuration, stimuli: CfgEvent): bool =
   result = (stimuli.kind == cfgKeyValuePair)


proc is_keyval_name(meta: Configuration, stimuli: CfgEvent): bool =
   result = (stimuli.kind == cfgKeyValuePair) and
            (stimuli.key == "name")


proc is_keyval_rule(meta: Configuration, stimuli: CfgEvent): bool =
   result = (stimuli.kind == cfgKeyValuePair) and
            (stimuli.key == "rule")


proc is_keyval_default(meta: Configuration, stimuli: CfgEvent): bool =
   result = (stimuli.kind == cfgKeyValuePair) and
            (stimuli.key == "default")


proc add_rule_dir(meta: var Configuration, stimuli: CfgEvent) =
   if stimuli.value == "":
      # The path is given without an explicit name.
      if stimuli.key == "":
         log.warning("Empty path given as rule directory in file '$#'.",
                     meta.filename)
         return

      var (head, tail) = split_path(stimuli.key)
      while (tail == "") and not (head == ""):
         (head, tail) = split_path(head)

      var path = expand_tilde(stimuli.key)
      if not is_absolute(path):
         path = meta.dir / path

      log.debug("Inferred name '$#' for rule dir '$#'.", tail, path)

      meta.rule_dirs.add(RuleDir.new(tail, path))
   else:
      # The path is given with an explicit name
      var path = expand_tilde(stimuli.value)
      if not is_absolute(path):
         path = meta.dir / path

      log.debug("Adding rule directory '$#' with name '$#'.",
                stimuli.value, stimuli.key)

      meta.rule_dirs.add(RuleDir.new(stimuli.key, path))


proc add_style(meta: var Configuration, stimuli: CfgEvent) =
   log.debug("Adding new style '$#'.", stimuli.value)
   meta.styles.add(Style.new(stimuli.value))


proc set_style_default(meta: var Configuration, stimuli: CfgEvent) =
   log.debug("  Setting as default style.")
   if (stimuli.value == "") or (stimuli.value.to_lower_ascii() == "true"):
      meta.styles[^1].is_default = true
   elif (stimuli.value.to_lower_ascii() == "false"):
      meta.styles[^1].is_default = false
   else:
      log.warning("Unsupported value given to the style keyword 'default', " &
                  "got '$#'.", stimuli.value)


proc add_style_rule(meta: var Configuration, stimuli: CfgEvent) =
   log.debug("  Adding new style rule '$#'.", stimuli.value)
   meta.styles[^1].rules.add(StyleRule.new(stimuli.value))


proc add_exception(meta: var Configuration, stimuli: CfgEvent) =
   log.debug("    Adding new exception '$#' to rule '$#'.",
             stimuli.key, meta.styles[^1].rules[^1].name)
   meta.styles[^1].rules[^1].exceptions.add(stimuli.key)


proc add_only(meta: var Configuration, stimuli: CfgEvent) =
   log.debug("    Adding new only '$#' to rule '$#'.",
             stimuli.key, meta.styles[^1].rules[^1].name)
   meta.styles[^1].rules[^1].only.add(stimuli.key)


proc parse_error(meta: var Configuration, stimuli: CfgEvent) =
   var tmp = ""
   case stimuli.kind
   of cfgSectionStart:
      tmp = "Unexpected section '$#'." % stimuli.section
   of cfgKeyValuePair:
      tmp = format("Unexpected key-value pair '$#' = '$#'.",
                   stimuli.key, stimuli.value)
   else:
      discard

   log.error("Failed to parse configuration file '$#'. $#", meta.filename, tmp)


proc get_default_style*(styles: seq[Style]): string =
   result = ""

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
         if (result == ""):
            result = style.name
         else:
            log.warning("Only one style may be set as the default. " &
                        "Ignoring default specifier for style '$#'.",
                        style.name)


proc get_cfg_file(): string =
   ## Returns the full path to a configuration file, if one exists.
   const CFG_FILENAME = @[".lins.cfg", "lins.cfg",
                          ".lins/.lins.cfg", ".lins/lins.cfg"]
   result = ""

   # Check for the environment variable 'LINS_CFG'. A valid configuration file
   # specified in this way takes precedence over the regular search.
   if exists_env("LINS_CFG"):
      let path = expand_tilde(get_env("LINS_CFG"))
      if file_exists(path):
         return path

   # Walk from the current directory up to the root directory searching for
   # a configuraiton file. Lastly, look in the user's home directory.
   for path in parent_dirs(expand_filename("./"), false, true):
      for filename in CFG_FILENAME:
         let tmp = path / filename
         if file_exists(tmp):
            return tmp

   for filename in CFG_FILENAME:
      let tmp = get_home_dir() / filename
      if file_exists(tmp):
         return tmp


proc parse_cfg_file*(): Configuration =
   let cfg_file = get_cfg_file()
   if cfg_file == "":
      log.info("Unable to find configuration file.")
      raise new_exception(ConfigurationFileNotFoundError,
                          "Unable to find configuration file.")
   else:
      log.info("Using configuration file '$#'.", cfg_file)

   var fs = new_file_stream(cfg_file, fmRead)
   if fs == nil:
      log.abort(ConfigurationPathError,
                format("Failed to open configuration file '$#' for reading.",
                       cfg_file))

   let (dir, _, _) = split_file(cfg_file)

   var p: CfgParser
   var sm: ConfigurationStateMachine =
      ConfigurationStateMachine(init_state: STATE1, dead_state_cb: parse_error)
   var meta = Configuration.new(cfg_file, dir)

   state_machine.reset(sm)

   open(p, fs, cfg_file)
   while true:
      var e = next(p)

      if (e.kind == cfgEof):
         log.debug("End of configuration file.")
         break
      else:
         state_machine.run(sm, meta, e)

      if is_dead(sm):
         # State machine has reached the dead state indicating an error in
         # the configuration file. We interpret this as an unrecoverable error
         # and abort the parsing.
         log.abort(ConfigurationParseError, "Parse error, aborting.")

   p.close()
   fs.close()

   result = meta
