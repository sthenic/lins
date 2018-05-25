import os
import ospaths
import parsecfg
import strutils
import streams

import ./log
import ../lexers/state_machine

type
   Configuration = object of RootObj
      filename: string
      rule_dirs: seq[string]

   ConfigurationState = State[Configuration, CfgEvent]
   ConfigurationTransition = Transition[Configuration, CfgEvent]
   ConfigurationStateMachine = StateMachine[Configuration, CfgEvent]


proc new(t: typedesc[Configuration], filename: string): Configuration =
   result = Configuration(filename: filename, rule_dirs: @[])


proc is_section_ruledirs(meta: Configuration, stimuli: CfgEvent): bool
proc is_section_style(meta: Configuration, stimuli: CfgEvent): bool
proc is_section_except(meta: Configuration, stimuli: CfgEvent): bool
proc is_section_only(meta: Configuration, stimuli: CfgEvent): bool
proc is_keyval(meta: Configuration, stimuli: CfgEvent): bool
proc is_keyval_name(meta: Configuration, stimuli: CfgEvent): bool
proc is_keyval_rule(meta: Configuration, stimuli: CfgEvent): bool

proc add_rule_dir(meta: var Configuration, stimuli: CfgEvent)


let
   STATE1 = ConfigurationState(id: 1, name: "Init", is_final: false)
   STATE2 = ConfigurationState(id: 2, name: "SecRuleDirs", is_final: false)
   STATE3 = ConfigurationState(id: 3, name: "AddRuleDir", is_final: false)
   STATE4 = ConfigurationState(id: 4, name: "SecStyle", is_final: false)
   STATE5 = ConfigurationState(id: 5, name: "AddStyleName", is_final: false)
   STATE6 = ConfigurationState(id: 6, name: "AddStyleRule", is_final: false)
   STATE7 = ConfigurationState(id: 7, name: "SecExcept", is_final: false)
   STATE8 = ConfigurationState(id: 8, name: "SecOnly", is_final: false)
   STATE9 = ConfigurationState(id: 9, name: "AddException", is_final: false)
   STATE10 = ConfigurationState(id: 10, name: "AddOnly", is_final: false)


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
                              next_state: STATE3)
   ]

STATE1.transitions = STATE1_TRANSITIONS
STATE2.transitions = STATE2_TRANSITIONS
STATE3.transitions = STATE3_TRANSITIONS

proc is_section_ruledirs(meta: Configuration, stimuli: CfgEvent): bool =
   result = (stimuli.kind == cfgSectionStart) and
            (stimuli.section == "RuleDirs")
   log.debug("Checking is RuleDirs: '$#'.", $result)


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

proc add_rule_dir(meta: var Configuration, stimuli: CfgEvent) =
   log.debug("Adding rule dir '$#'.", stimuli.key)
   meta.rule_dirs.add(stimuli.key)


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


proc get_cfg_file(): string =
   ## Walk from the current directory up to the root directory searching for
   ## a configuraiton file. Lastly, look in the user's home directory.
   const CFG_FILENAME = ".lins.cfg"
   result = ""

   for path in parent_dirs(expand_filename("./"), false, true):
      let tmp = path / CFG_FILENAME
      if file_exists(tmp):
         return tmp

   let tmp = get_home_dir() / CFG_FILENAME
   if file_exists(tmp):
      return tmp

proc parse_cfg_file*() =
   let cfg_file = get_cfg_file()
   if cfg_file == "":
      log.info("Unable to find configuration file.")
   else:
      log.info("Using configuration file '$#'.", cfg_file)

   var fs = newFileStream(cfg_file, fmRead)
   if fs == nil:
      log.error("Failed to open configuration file '$#' for reading.", cfg_file)
      quit(-1)

   var p: CfgParser
   var sm: ConfigurationStateMachine =
      ConfigurationStateMachine(init_state: STATE1, dead_state_cb: parse_error)
   var meta = Configuration.new(cfg_file)

   state_machine.reset(sm)

   open(p, fs, cfg_file)
   while true:
      var e = next(p)

      if (e.kind == cfgEof):
         log.debug("End of configuration file.")
         break
      else:
         log.debug("Running state machine.")
         state_machine.run(sm, meta, e)

   p.close()
   fs.close()


when isMainModule:
   parse_cfg_file()
