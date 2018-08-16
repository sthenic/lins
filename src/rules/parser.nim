import yaml.serialization
import streams
import tables
import typetraits
import strutils
import strformat
import sequtils
import os
import ospaths
import nre
import terminal

import ./rules
import ../utils/log
import ../utils/cli
import ../utils/cfg

type
   RuleValueError = object of Exception
   RuleParseError = object of Exception
   RulePathError* = object of Exception

type
   ExistenceYAML = object
      extends: string
      message: string
      level: string
      ignorecase: bool
      nonword: bool
      raw: seq[string]
      tokens: seq[string]
      debug: bool

   SubstitutionYAML = object
      extends: string
      message: string
      level: string
      ignorecase: bool
      nonword: bool
      swap: Table[string, string]
      debug: bool

   OccurrenceYAML = object
      extends: string
      message: string
      level: string
      ignorecase: bool
      scope: string
      limit: int
      limit_kind: string
      token: string
      debug: bool

   RepetitionYAML = object
      extends: string
      message: string
      level: string
      ignorecase: bool
      scope: string
      token: string
      debug: bool

   ConsistencyYAML = object
      extends: string
      message: string
      level: string
      ignorecase: bool
      nonword: bool
      scope: string
      either: Table[string, string]
      debug: bool

   DefinitionYAML = object
      extends: string
      message: string
      level: string
      ignorecase: bool
      scope: string
      definition: string
      declaration: string
      exceptions: seq[string]
      debug: bool

   ConditionalYAML = object
      extends: string
      message: string
      level: string
      ignorecase: bool
      scope: string
      first: string
      second: string
      debug: bool

   Rules = tuple
      existence: ExistenceYAML
      substitution: SubstitutionYAML
      occurrence: OccurrenceYAML
      repetition: RepetitionYAML
      consistency: ConsistencyYAML
      definition: DefinitionYAML
      conditional: ConditionalYAML

# Default values for YAML objects
set_default_value(ExistenceYAML, ignorecase, false)
set_default_value(SubstitutionYAML, ignorecase, false)
set_default_value(OccurrenceYAML, ignorecase, false)
set_default_value(RepetitionYAML, ignorecase, false)
set_default_value(ConsistencyYAML, ignorecase, false)
set_default_value(DefinitionYAML, ignorecase, false)
set_default_value(ConditionalYAML, ignorecase, false)

set_default_value(ExistenceYAML, debug, false)
set_default_value(SubstitutionYAML, debug, false)
set_default_value(OccurrenceYAML, debug, false)
set_default_value(RepetitionYAML, debug, false)
set_default_value(ConsistencyYAML, debug, false)
set_default_value(DefinitionYAML, debug, false)
set_default_value(ConditionalYAML, debug, false)

set_default_value(ExistenceYAML, nonword, false)
set_default_value(ExistenceYAML, raw, @[])
set_default_value(ExistenceYAML, tokens, @[])

set_default_value(SubstitutionYAML, nonword, false)

set_default_value(ConsistencyYAML, nonword, false)

set_default_value(DefinitionYAML, definition,
                  r"(?:\b[A-Z][a-z]+ )+\(([A-Z]{3,5})\)")
set_default_value(DefinitionYAML, declaration, r"\b([A-Z]{3,5})\b")
set_default_value(DefinitionYAML, exceptions, @[])


proc new(t: typedesc[ExistenceYAML]): ExistenceYAML =
   result = ExistenceYAML(extends: "existence",
                          message: "",
                          level: "",
                          ignorecase: false,
                          nonword: false,
                          tokens: @[])


proc new(t: typedesc[SubstitutionYAML]): SubstitutionYAML =
   result = SubstitutionYAML(extends: "substitution",
                             message: "",
                             level: "",
                             ignorecase: false,
                             nonword: false,
                             swap: init_table[string, string]())


proc new(t: typedesc[OccurrenceYAML]): OccurrenceYAML =
   result = OccurrenceYAML(extends: "occurrence",
                           message: "",
                           level: "",
                           ignorecase: false,
                           scope: "",
                           limit: 0,
                           limit_kind: "",
                           token: "")


proc new(t: typedesc[RepetitionYAML]): RepetitionYAML =
   result = RepetitionYAML(extends: "repetition",
                           message: "",
                           level: "",
                           ignorecase: false,
                           scope: "",
                           token: "")


proc new(t: typedesc[ConsistencyYAML]): ConsistencyYAML =
   result = ConsistencyYAML(extends: "consistency",
                            message: "",
                            level: "",
                            ignorecase: false,
                            nonword: false,
                            scope: "",
                            either: init_table[string, string]())


proc new(t: typedesc[DefinitionYAML]): DefinitionYAML =
   result = DefinitionYAML(extends: "definition",
                           message: "",
                           level: "",
                           ignorecase: false,
                           scope: "",
                           definition: "",
                           declaration: "",
                           exceptions: @[])


proc new(t: typedesc[ConditionalYAML]): ConditionalYAML =
   result = ConditionalYAML(extends: "conditional",
                            message: "",
                            level: "",
                            ignorecase: false,
                            scope: "",
                            first: "",
                            second: "")


proc new(t: typedesc[Rules]): Rules =
   result = (existence: ExistenceYAML.new(),
             substitution: SubstitutionYAML.new(),
             occurrence: OccurrenceYAML.new(),
             repetition: RepetitionYAML.new(),
             consistency: ConsistencyYAML.new(),
             definition: DefinitionYAML.new(),
             conditional: ConditionalYAML.new())


template validate_extension_point(data: typed, ext: string, filename: string) =
   if not (to_lower_ascii(data.extends) == ext):
      log.abort(RuleValueError,
                "Invalid extension point '$#' specified in file '$#'.",
                data.extends, filename)


template validate_common(data: typed, filename: string, message: untyped,
                         ignore_case: untyped, level: untyped) =
   ## Validate common rule parameters
   var
      message: string = data.message
      ignore_case: bool = data.ignore_case
      level: Severity

   case to_lower_ascii(data.level)
   of "suggestion":
      level = Severity.SUGGESTION
   of "warning":
      level = Severity.WARNING
   of "error":
      level = Severity.ERROR
   else:
      log.warning("Unsupported severity level '$#' defined for rule in " &
                  "file '$#', skipping.", data.level, filename)
      raise new_exception(RuleValueError, "Unsupported severity level in " &
                                          "file '" & filename & "'")


template validate_scope(data: typed, filename: string, scope: untyped) =
   ## Validate scope
   var scope: Scope

   case to_lower_ascii(data.scope)
   of "text":
      scope = Scope.TEXT
   of "paragraph":
      scope = Scope.PARAGRAPH
   of "sentence":
      scope = Scope.SENTENCE
   else:
      log.warning("Unsupported scope '$#' defined for rule in file '$#', " &
                  "skipping.", data.scope, filename)
      raise new_exception(RuleValueError, "Unsupported scope in file '" &
                                          filename & "'")


template validate_limit(data: typed, filename: string, limit: untyped,
                        limit_kind: untyped) =
   ## Validate limit and limit kind
   var
      limit: int = data.limit
      limit_kind: Limit

   case to_lower_ascii(data.limit_kind):
   of "min", "minimum":
      limit_kind = Limit.MIN
   of "max", "maximum":
      limit_kind = Limit.MAX
   else:
      log.warning("Unsupported limit kind '$#' defined for rule in file " &
                  "'$#', skipping.", data.scope, filename)
      raise new_exception(RuleValueError, "Unsupported limit kind in file '" &
                                          filename & "'")


template validate_nof_capture_groups(regex: string, filename: string,
                                     label: string, nof_capture_groups: int) =
   var tmp = "group"
   if nof_capture_groups > 1:
      tmp &= "s"
   let cc = capture_count(re(regex))
   if not (cc == nof_capture_groups):
      log.warning("The regular expression defined for field '$#' in file " &
                  "'$#' is expected to have exactly $# capture $#, not $#. " &
                  "Skipping the file.",
                  label, filename, $nof_capture_groups, tmp, $cc)
      raise new_exception(RuleValueError, "Expected " & $nof_capture_groups &
                                          " capture " & tmp & ".")


proc get_rule_display_name(rule_filename: string): string =
   var (dir, name, _) = split_file(rule_filename)
   if name == "":
      log.abort(RulePathError,
                "Attempted to get short name for an invalid path '$#'.",
                rule_filename)

   if dir == "":
      result = name
   else:
      var (head, tail) = split_path(dir)
      while (tail == "") and not (head == ""):
         (head, tail) = split_path(head)

      result = tail & "." & name


template debug_header(data: typed, filename: string) =
   if data.debug:
      log.debug_always("Debug information for rule '$#'.", filename)


template debug_existence(data: typed, filename, token_str: string) =
   debug_header(data, filename)
   if data.debug:
      log.debug_always("  $#", token_str)


template debug_substitution(data: typed, filename, key_str: string) =
   debug_header(data, filename)
   if data.debug:
      log.debug_always("  $#", key_str)


template debug_occurrence(data: typed, filename: string) =
   debug_header(data, filename)
   if data.debug:
      log.debug_always("  $#", data.token)


template debug_repetition(data: typed, filename: string) =
   debug_header(data, filename)
   if data.debug:
      log.debug_always("  $#", data.token)


template debug_consistency_entry(data: typed, first, second: string) =
   if data.debug:
      log.debug_always("  First:  $#", first)
      log.debug_always("  Second: $#", second)


template debug_definition(data: typed, filename: string) =
   debug_header(data, filename)
   if data.debug:
      log.debug_always("  Definition:  $#", data.definition)
      log.debug_always("  Declaration: $#", data.declaration)


template debug_conditional(data: typed, filename: string) =
   debug_header(data, filename)
   if data.debug:
      log.debug_always("  First:  $#", data.first)
      log.debug_always("  Second: $#", data.second)


proc parse_rule(data: ExistenceYAML, filename: string): seq[Rule] =
   ## Parse and validate YAML data for the rule 'existence' and return a
   ## sequence of RuleExistence objects.
   result = @[]

   validate_extension_point(data, "existence", filename)
   validate_common(data, filename, message, ignore_case, level)

   var word_boundary: string
   if data.nonword:
      word_boundary = ""
   else:
      word_boundary = r"\b"

   var
      token_str = ""
      raw_is_defined = false
      tokens_are_defined = false

   if not (data.raw == @[]):
      for r in data.raw:
         token_str &= r
      raw_is_defined = true

   if not (data.tokens == @[]):
      token_str &= word_boundary & "(" & data.tokens[0]
      for i in 1..<data.tokens.len:
         token_str &= "|" & data.tokens[i]
      token_str &= ")" & word_boundary
      tokens_are_defined = true

   if not raw_is_defined and not tokens_are_defined:
      log.warning("Neither tokens nor raw items are defined for rule in file " &
                  "'$#', skipping.", filename)
      raise new_exception(RuleParseError,
                          format("Missing either tokens or raw items for " &
                                 "rule in file '$#'.", filename))

   debug_existence(data, filename, token_str)

   let display_name = get_rule_display_name(filename)
   result.add(RuleExistence.new(level, message, filename, display_name,
                                token_str, ignore_case))


proc parse_rule(data: SubstitutionYAML, filename: string): seq[Rule] =
   ## Parse and validate YAML data for the rule 'substitution' and return a
   ## sequence of RuleSubstitution objects.
   result = @[]

   validate_extension_point(data, "substitution", filename)
   validate_common(data, filename, message, ignore_case, level)

   var word_boundary: string
   if data.nonword:
      word_boundary = ""
   else:
      word_boundary = r"\b"

   var key_str = word_boundary & "("
   var subst_table = init_table[string, string]()
   for key, subst in pairs(data.swap):
      key_str &= key & "|"
      if subst == "":
         log.warning("Empty substitution for key '$#' in file '$#'.",
                     key, filename)
      subst_table[key] = subst
   key_str = key_str[0..^2] & ")" & word_boundary

   debug_substitution(data, filename, key_str)

   let display_name = get_rule_display_name(filename)
   result.add(RuleSubstitution.new(level, message, filename, display_name,
                                   key_str, subst_table, ignore_case))


proc parse_rule(data: OccurrenceYAML, filename: string): seq[Rule] =
   ## Parse and validate YAML data for the rule 'occurrence' and return a
   ## sequence of RuleOccurrence objects.
   result = @[]

   validate_extension_point(data, "occurrence", filename)
   validate_common(data, filename, message, ignore_case, level)
   validate_scope(data, filename, scope)
   validate_limit(data, filename, limit, limit_kind)

   debug_occurrence(data, filename)

   let display_name = get_rule_display_name(filename)
   result.add(RuleOccurrence.new(level, message, filename, display_name,
                                 data.token, limit, limit_kind, scope, ignore_case))


proc parse_rule(data: RepetitionYAML, filename: string): seq[Rule] =
   ## Parse and validate YAML data for the rule 'repetition' and return a
   ## sequence of RuleRepetition objects.
   result = @[]

   validate_extension_point(data, "repetition", filename)
   validate_common(data, filename, message, ignore_case, level)
   validate_scope(data, filename, scope)

   debug_repetition(data, filename)

   let display_name = get_rule_display_name(filename)
   result.add(RuleRepetition.new(level, message, filename, display_name,
                                 data.token, scope, ignore_case))


proc parse_rule(data: ConsistencyYAML, filename: string): seq[Rule] =
   ## Parse and validate YAML data for the rule 'consistency' and return a
   ## sequence of RuleConsistency objects.
   result = @[]

   validate_extension_point(data, "consistency", filename)
   validate_common(data, filename, message, ignore_case, level)
   validate_scope(data, filename, scope)

   var word_boundary: tuple[l: string, r: string]
   if data.nonword:
      word_boundary = ("", "")
   else:
      word_boundary = (r"\b(", r")\b")

   debug_header(data, filename)

   let display_name = get_rule_display_name(filename)
   for first, second in pairs(data.either):
      let lfirst = word_boundary.l & first & word_boundary.r
      let lsecond = word_boundary.l & second & word_boundary.r

      debug_consistency_entry(data, lfirst, lsecond)

      result.add(RuleConsistency.new(level, message, filename, display_name,
                                     lfirst, lsecond, scope, ignore_case))


proc parse_rule(data: DefinitionYAML, filename: string): seq[Rule] =
   ## Parse and validate YAML data for the rule 'definition' and return a
   ## sequence of RuleDefinition objects.
   result = @[]

   validate_extension_point(data, "definition", filename)
   validate_common(data, filename, message, ignore_case, level)
   validate_scope(data, filename, scope)
   validate_nof_capture_groups(data.declaration, filename, "declaration", 1)
   validate_nof_capture_groups(data.definition, filename, "definition", 1)

   debug_definition(data, filename)

   let display_name = get_rule_display_name(filename)
   result.add(RuleDefinition.new(level, message, filename, display_name,
                                 data.definition, data.declaration,
                                 data.exceptions, scope, ignore_case))


proc parse_rule(data: ConditionalYAML, filename: string): seq[Rule] =
   ## Parse and validate YAML data for the rule 'definition' and return a
   ## sequence of RuleDefinition objects.
   result = @[]

   validate_extension_point(data, "conditional", filename)
   validate_common(data, filename, message, ignore_case, level)
   validate_scope(data, filename, scope)
   validate_nof_capture_groups(data.first, filename, "first", 1)
   validate_nof_capture_groups(data.second, filename, "second", 1)

   debug_conditional(data, filename)

   let display_name = get_rule_display_name(filename)
   result.add(RuleConditional.new(level, message, filename, display_name,
                                  data.first, data.second, scope, ignore_case))


proc parse_rule_file*(filename: string): seq[Rule] =
   ##  Parse a YAML-formatted rule file and return a list of rule objects.
   ##
   ##  This function raises RuleValueError when a field has an unexpected or an
   ##  unsupported value.
   var
      fs: FileStream
      success = false
      data = Rules.new()

   # Open the stream
   fs = new_file_stream(filename)
   if is_nil(fs):
      log.warning("Rule file '$#' is not a valid path, skipping.", filename)
      raise new_exception(RulePathError, "Rule file '" & filename &
                                         "' is not a valid path, skipping.")

   for f in data.fields:
      try:
         load(fs, f)
         result = parse_rule(f, filename)
         success = true
         break
      except YamlConstructionError:
         fs.set_position(0)

   fs.close()

   if not success:
      log.abort(RuleParseError,
                "Parse error in file '$#'. Either it's not a valid YAML " &
                "file or it doesn't specify the required fields for the " &
                "extension point. Skipping for now.", filename)


type Mode* = enum NonRecursive, Recursive

proc parse_rule_dir*(rule_root_dir: string, strategy: Mode): seq[Rule] =
   if not os.dir_exists(rule_root_dir):
      log.abort(RulePathError, "Invalid path '$1'.", rule_root_dir)

   result = @[]

   case strategy
   of NonRecursive:
      for kind, path in walk_dir(rule_root_dir):
         # Skip directories.
         if (kind == pcDir) or (kind == pcLinkToDir):
            continue

         let (_, _, ext) = split_file(path)

         if not (ext == ".yml"):
            continue

         try:
            result = concat(result, parse_rule_file(path))
         except RuleValueError:
            discard
         except RuleParseError:
            discard
         except RulePathError:
            discard

   of Recursive:
      for path in walk_dir_rec(rule_root_dir):
         let (_, _, ext) = split_file(path)

         if not (ext == ".yml"):
            continue

         try:
            result = concat(result, parse_rule_file(path))
         except RuleValueError:
            discard
         except RuleParseError:
            discard
         except RulePathError:
            discard

type
   Database = tuple[
      rules: Table[string, seq[Rule]],
      styles: Table[string, seq[Rule]]
   ]

proc build_databases(cfg_state: Configuration): Database =
   result = (
      init_table[string, seq[Rule]](),
      init_table[string, seq[Rule]]()
   )

   # Walk through the rule directories specified in the configuration file
   # and build rule objects.
   try:
      for dir in cfg_state.rule_dirs:
         result.rules[dir.name] = parse_rule_dir(dir.path, NonRecursive)
   except RulePathError:
      discard

   # Build styles
   for style in cfg_state.styles:
      log.debug("Building rule objects for style '$1'.", style.name)

      result.styles[style.name] = @[]

      for rule in style.rules:
         var nof_robj = 0
         # Protect against access violations with undefined keys.
         if not result.rules.has_key(rule.name):
            log.warning("Undefined rule name '$1' in configuration file " &
                        "'$2', skipping.", rule.name, cfg_state.filename)
            continue

         if not (rule.exceptions == @[]):
            # Add every rule object except the ones whose source file matches
            # an exception.
            log.debug("Adding rule objects from exceptions.")
            for robj in result.rules[rule.name]:
               let (_, filename, _) = split_file(robj.source_file)
               if not (filename in rule.exceptions):
                  result.styles[style.name].add(robj)
                  nof_robj += 1

         elif not (rule.only == @[]):
            # Only add rule object whose source file matches an 'only' item.
            for robj in result.rules[rule.name]:
               let (_, filename, _) = split_file(robj.source_file)
               if (filename in rule.only):
                  result.styles[style.name].add(robj)
                  nof_robj += 1

         else:
            # Add every rule object.
            result.styles[style.name].add(result.rules[rule.name])
            nof_robj = result.rules[rule.name].len

         log.debug("  Adding $1 rule objects from '$2'.", $nof_robj, rule.name)


proc get_rules*(cfg_state: Configuration, cli_state: CLIState): seq[Rule] =
   ## Return a sequence of rules given the current configuration and CLI state.
   result = @[]

   if cli_state.no_cfg:
      return result

   # Build rule database and retrieve the name of the default style.
   var (rule_db, style_db) = build_databases(cfg_state)
   let default_style = get_default_style(cfg_state.styles)

   # Add rules from rule directories specified on the command line.
   if not (cli_state.rule_dirs == @[]):
      for dir in cli_state.rule_dirs:
         try:
            result.add(parse_rule_dir(dir, NonRecursive))
         except RulePathError:
            discard

   # Add named rule sets speficied on the command line.
   if not (cli_state.rules == @[]):
      for rule_name in cli_state.rules:
         try:
            result.add(rule_db[rule_name])
         except KeyError:
            log.warning("No definition for rule '$1' found in configuration " &
                        "file, skipping.", rule_name)

   # Add named styles specified on the command line. If no style is specified,
   # attempt to use the default style.
   if not (cli_state.styles == @[]):
      for style in cli_state.styles:
         try:
            result.add(style_db[style])
         except KeyError:
            log.warning("Undefined style '$1'.", style)
   elif not cli_state.no_default and not (default_style == ""):
      # Default style specified.
      log.info("Using default style '$1'.", default_style)
      result.add(style_db[default_style])


proc list*(cfg_state: Configuration, cli_state: CLIState) =
   # Temporarily suppress log messages.
   log.push_quiet_mode(true)

   # List styles.
   let (_, style_db) = build_databases(cfg_state)

   call_styled_write_line(styleBright, styleUnderscore, "Styles", resetStyle)

   for style_name, rules in style_db:
      call_styled_write_line(styleBright, &"  {style_name:<15}", resetStyle)
      call_styled_write_line("    ", $len(rules), " rules")

   # List current rule set.
   call_styled_write_line("\n", styleBright, styleUnderscore,
                          "Current rule set", resetStyle)
   var seen: seq[string] = @[]
   for rule in get_rules(cfg_state, cli_state):
      if rule.source_file in seen:
         continue
      call_styled_write_line(styleBright, &"  {rule.display_name:<30}",
                             resetStyle, rule.source_file)

      seen.add(rule.source_file)

   if seen == @[]:
      echo "  No rule files."

   # Restore the log state.
   log.pop_quiet_mode()
