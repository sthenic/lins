import os
import ospaths
import parsecfg
import strutils
import streams

import ./log
import ../lexers/state_machine

type
   CfgFileNotFoundError* = object of Exception
   CfgPathError* = object of Exception
   CfgParseError* = object of Exception

type
   CfgState* = object of RootObj
      filename*: string
      dir*: string
      rule_dirs*: seq[CfgRuleDir]
      styles*: seq[CfgStyle]

   CfgRuleDir* = object of RootObj
      name*: string
      path*: string

   CfgStyle* = object of RootObj
      name*: string
      is_default*: bool
      rules*: seq[CfgStyleRule]

   CfgStyleRule* = object of RootObj
      name*: string
      exceptions*: seq[string]
      only*: seq[string]

   CfgFSMState = State[CfgState, CfgEvent]
   CfgFSMTransition = Transition[CfgState, CfgEvent]
   CfgFSM = StateMachine[CfgState, CfgEvent]


proc new(t: typedesc[CfgState], filename, dir: string): CfgState =
   result = CfgState(filename: filename, dir: dir, rule_dirs: @[], styles: @[])


proc new(t: typedesc[CfgRuleDir], name, path: string): CfgRuleDir =
   result = CfgRuleDir(name: name, path: path)


proc new(t: typedesc[CfgStyle], name: string): CfgStyle =
   result = CfgStyle(name: name, is_default: false, rules: @[])


proc new(t: typedesc[CfgStyleRule], name: string): CfgStyleRule =
   result = CfgStyleRule(name: name, exceptions: @[], only: @[])


proc is_section_ruledirs(meta: CfgState, stimuli: CfgEvent): bool
proc is_section_style(meta: CfgState, stimuli: CfgEvent): bool
proc is_section_except(meta: CfgState, stimuli: CfgEvent): bool
proc is_section_only(meta: CfgState, stimuli: CfgEvent): bool
proc is_keyval(meta: CfgState, stimuli: CfgEvent): bool
proc is_keyval_name(meta: CfgState, stimuli: CfgEvent): bool
proc is_keyval_rule(meta: CfgState, stimuli: CfgEvent): bool
proc is_keyval_default(meta: CfgState, stimuli: CfgEvent): bool

proc add_rule_dir(meta: var CfgState, stimuli: CfgEvent)
proc add_style(meta: var CfgState, stimuli: CfgEvent)
proc set_style_default(meta: var CfgState, stimuli: CfgEvent)
proc add_style_rule(meta: var CfgState, stimuli: CfgEvent)
proc add_exception(meta: var CfgState, stimuli: CfgEvent)
proc add_only(meta: var CfgState, stimuli: CfgEvent)

let
   STATE1 = CfgFSMState(id: 1, name: "Init", is_final: false)
   STATE2 = CfgFSMState(id: 2, name: "SecRuleDirs", is_final: false)
   STATE3 = CfgFSMState(id: 3, name: "AddRuleDir", is_final: false)
   STATE4 = CfgFSMState(id: 4, name: "SecStyle", is_final: false)
   STATE5 = CfgFSMState(id: 5, name: "AddStyle", is_final: false)
   STATE6 = CfgFSMState(id: 6, name: "AddStyleRule", is_final: false)
   STATE7 = CfgFSMState(id: 7, name: "SecExcept", is_final: false)
   STATE8 = CfgFSMState(id: 8, name: "SecOnly", is_final: false)
   STATE9 = CfgFSMState(id: 9, name: "AddException", is_final: false)
   STATE10 = CfgFSMState(id: 10, name: "AddOnly", is_final: false)
   STATE11 = CfgFSMState(id: 11, name: "SetDefault", is_final: false)


let
   STATE1_TRANSITIONS = @[
      CfgFSMTransition(condition_cb: is_section_ruledirs,
                              transition_cb: nil,
                              next_state: STATE2),
      CfgFSMTransition(condition_cb: is_section_style,
                              transition_cb: nil,
                              next_state: STATE4)
   ]
   STATE2_TRANSITIONS = @[
      CfgFSMTransition(condition_cb: is_keyval,
                              transition_cb: add_rule_dir,
                              next_state: STATE3)
   ]
   STATE3_TRANSITIONS = @[
      CfgFSMTransition(condition_cb: is_keyval,
                              transition_cb: add_rule_dir,
                              next_state: STATE3),
      CfgFSMTransition(condition_cb: is_section_style,
                              transition_cb: nil,
                              next_state: STATE4)
   ]
   STATE4_TRANSITIONS = @[
      CfgFSMTransition(condition_cb: is_keyval_name,
                              transition_cb: add_style,
                              next_state: STATE5)
   ]
   STATE5_TRANSITIONS = @[
      CfgFSMTransition(condition_cb: is_keyval_rule,
                              transition_cb: add_style_rule,
                              next_state: STATE6),
      CfgFSMTransition(condition_cb: is_keyval_default,
                              transition_cb: set_style_default,
                              next_state: STATE11)
   ]
   STATE6_TRANSITIONS = @[
      CfgFSMTransition(condition_cb: is_keyval_rule,
                              transition_cb: add_style_rule,
                              next_state: STATE6),
      CfgFSMTransition(condition_cb: is_keyval_default,
                              transition_cb: set_style_default,
                              next_state: STATE11),
      CfgFSMTransition(condition_cb: is_section_except,
                              transition_cb: nil,
                              next_state: STATE7),
      CfgFSMTransition(condition_cb: is_section_only,
                              transition_cb: nil,
                              next_state: STATE8),
      CfgFSMTransition(condition_cb: is_section_style,
                              transition_cb: nil,
                              next_state: STATE4)
   ]
   STATE7_TRANSITIONS = @[
      CfgFSMTransition(condition_cb: is_keyval,
                              transition_cb: add_exception,
                              next_state: STATE9)
   ]
   STATE8_TRANSITIONS = @[
      CfgFSMTransition(condition_cb: is_keyval,
                              transition_cb: add_only,
                              next_state: STATE10)
   ]
   STATE9_TRANSITIONS = @[
      CfgFSMTransition(condition_cb: is_keyval_rule,
                              transition_cb: add_style_rule,
                              next_state: STATE6),
      CfgFSMTransition(condition_cb: is_keyval,
                              transition_cb: add_exception,
                              next_state: STATE9),
      CfgFSMTransition(condition_cb: is_section_style,
                              transition_cb: nil,
                              next_state: STATE4)
   ]
   STATE10_TRANSITIONS = @[
      CfgFSMTransition(condition_cb: is_keyval_rule,
                              transition_cb: add_style_rule,
                              next_state: STATE6),
      CfgFSMTransition(condition_cb: is_keyval,
                              transition_cb: add_only,
                              next_state: STATE10),
      CfgFSMTransition(condition_cb: is_section_style,
                              transition_cb: nil,
                              next_state: STATE4)
   ]
   STATE11_TRANSITIONS = @[
      CfgFSMTransition(condition_cb: is_keyval_rule,
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


proc is_section_ruledirs(meta: CfgState, stimuli: CfgEvent): bool =
   result = (stimuli.kind == cfgSectionStart) and
            (stimuli.section == "RuleDirs")


proc is_section_style(meta: CfgState, stimuli: CfgEvent): bool =
   result = (stimuli.kind == cfgSectionStart) and
            (stimuli.section == "Style")


proc is_section_except(meta: CfgState, stimuli: CfgEvent): bool =
   result = (stimuli.kind == cfgSectionStart) and
            (stimuli.section == "Except")


proc is_section_only(meta: CfgState, stimuli: CfgEvent): bool =
   result = (stimuli.kind == cfgSectionStart) and
            (stimuli.section == "Only")


proc is_keyval(meta: CfgState, stimuli: CfgEvent): bool =
   result = (stimuli.kind == cfgKeyValuePair)


proc is_keyval_name(meta: CfgState, stimuli: CfgEvent): bool =
   result = (stimuli.kind == cfgKeyValuePair) and
            (stimuli.key == "name")


proc is_keyval_rule(meta: CfgState, stimuli: CfgEvent): bool =
   result = (stimuli.kind == cfgKeyValuePair) and
            (stimuli.key == "rule")


proc is_keyval_default(meta: CfgState, stimuli: CfgEvent): bool =
   result = (stimuli.kind == cfgKeyValuePair) and
            (stimuli.key == "default")


proc add_rule_dir(meta: var CfgState, stimuli: CfgEvent) =
   if stimuli.value == "":
      # The path is given without an explicit name.
      if stimuli.key == "":
         log.warning("Empty path given as rule directory in file '$1'.",
                     meta.filename)
         return

      var (head, tail) = split_path(stimuli.key)
      while (tail == "") and not (head == ""):
         (head, tail) = split_path(head)

      var path = expand_tilde(stimuli.key)
      if not is_absolute(path):
         path = meta.dir / path

      log.debug("Inferred name '$1' for rule dir '$2'.", tail, path)

      meta.rule_dirs.add(CfgRuleDir.new(tail, path))
   else:
      # The path is given with an explicit name
      var path = expand_tilde(stimuli.value)
      if not is_absolute(path):
         path = meta.dir / path

      log.debug("Adding rule directory '$1' with name '$2'.",
                stimuli.value, stimuli.key)

      meta.rule_dirs.add(CfgRuleDir.new(stimuli.key, path))


proc add_style(meta: var CfgState, stimuli: CfgEvent) =
   log.debug("Adding new style '$1'.", stimuli.value)
   meta.styles.add(CfgStyle.new(stimuli.value))


proc set_style_default(meta: var CfgState, stimuli: CfgEvent) =
   log.debug("  Setting as default style.")
   if (stimuli.value == "") or (stimuli.value.to_lower_ascii() == "true"):
      meta.styles[^1].is_default = true
   elif (stimuli.value.to_lower_ascii() == "false"):
      meta.styles[^1].is_default = false
   else:
      log.warning("Unsupported value given to the style keyword 'default', " &
                  "got '$1'.", stimuli.value)


proc add_style_rule(meta: var CfgState, stimuli: CfgEvent) =
   log.debug("  Adding new style rule '$1'.", stimuli.value)
   meta.styles[^1].rules.add(CfgStyleRule.new(stimuli.value))


proc add_exception(meta: var CfgState, stimuli: CfgEvent) =
   log.debug("    Adding new exception '$1' to rule '$2'.",
             stimuli.key, meta.styles[^1].rules[^1].name)
   meta.styles[^1].rules[^1].exceptions.add(stimuli.key)


proc add_only(meta: var CfgState, stimuli: CfgEvent) =
   log.debug("    Adding new only '$1' to rule '$2'.",
             stimuli.key, meta.styles[^1].rules[^1].name)
   meta.styles[^1].rules[^1].only.add(stimuli.key)


proc parse_error(meta: var CfgState, stimuli: CfgEvent) =
   var tmp = ""
   case stimuli.kind
   of cfgSectionStart:
      tmp = "Unexpected section '$1'." % stimuli.section
   of cfgKeyValuePair:
      tmp = format("Unexpected key-value pair '$1' = '$2'.",
                   stimuli.key, stimuli.value)
   else:
      discard

   log.error("Failed to parse configuration file '$1'. $2", meta.filename, tmp)


proc get_default_style*(styles: seq[CfgStyle]): string =
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
                        "Ignoring default specifier for style '$1'.",
                        style.name)


proc get_cfg_file(): string =
   ## Returns the full path to a configuration file, if one exists.
   const FILENAMES = @[".lins.cfg", "lins.cfg",
                       ".lins/.lins.cfg", ".lins/lins.cfg"]
   const FILENAMES_CFGDIR = @["lins/.lins.cfg", "lins/lins.cfg"]
   result = ""

   # Check for the environment variable 'LINS_CFG'. A valid configuration file
   # specified in this way takes precedence over the regular search.
   if exists_env("LINS_CFG"):
      let path = expand_tilde(get_env("LINS_CFG"))
      if file_exists(path):
         return path
      else:
         log.warning("Environment variable 'LINS_CFG' ('$1') does not " &
                     "specify an existing file.", path)

   # Walk from the current directory up to the root directory searching for
   # a configuraiton file.
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


proc parse_cfg_file*(): CfgState =
   let cfg_file = get_cfg_file()
   if cfg_file == "":
      log.info("Unable to find configuration file.")
      raise new_exception(CfgFileNotFoundError,
                          "Unable to find configuration file.")
   else:
      log.info("Using configuration file '$1'.", cfg_file)

   var fs = new_file_stream(cfg_file, fmRead)
   if fs == nil:
      log.abort(CfgPathError,
                format("Failed to open configuration file '$1' for reading.",
                       cfg_file))

   let (dir, _, _) = split_file(cfg_file)

   var
      p: CfgParser
      sm = CfgFSM(init_state: STATE1, dead_state_cb: parse_error)
      meta = CfgState.new(cfg_file, dir)

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
         log.abort(CfgParseError, "Parse error, aborting.")

   p.close()
   fs.close()

   result = meta
