import yaml.serialization
import streams
import tables
import typetraits
import strutils
import sequtils
import os
import ospaths
import nre

import ./rules
import ../utils/log

type
   RuleValueError = object of Exception
   RuleParseError = object of Exception
   RulePathError = object of Exception

type
   ExistenceYAML = object
      extends: string
      message: string
      level: string
      ignorecase: bool
      nonword: bool
      raw: seq[string]
      tokens: seq[string]

   SubstitutionYAML = object
      extends: string
      message: string
      level: string
      ignorecase: bool
      nonword: bool
      swap: Table[string, string]

   OccurrenceYAML = object
      extends: string
      message: string
      level: string
      ignorecase: bool
      scope: string
      limit: int
      limit_kind: string
      token: string

   RepetitionYAML = object
      extends: string
      message: string
      level: string
      ignorecase: bool
      scope: string
      token: string

   ConsistencyYAML = object
      extends: string
      message: string
      level: string
      ignorecase: bool
      scope: string
      either: Table[string, string]

   DefinitionYAML = object
      extends: string
      message: string
      level: string
      ignorecase: bool
      scope: string
      definition: string
      declaration: string
      exceptions: seq[string]

   Rules = tuple
      existence: ExistenceYAML
      substitution: SubstitutionYAML
      occurrence: OccurrenceYAML
      repetition: RepetitionYAML
      consistency: ConsistencyYAML
      definition: DefinitionYAML

# Default values for YAML objects
set_default_value(ExistenceYAML, ignorecase, false)
set_default_value(SubstitutionYAML, ignorecase, false)
set_default_value(OccurrenceYAML, ignorecase, false)
set_default_value(RepetitionYAML, ignorecase, false)
set_default_value(ConsistencyYAML, ignorecase, false)
set_default_value(DefinitionYAML, ignorecase, false)

set_default_value(ExistenceYAML, nonword, false)
set_default_value(ExistenceYAML, raw, @[])
set_default_value(ExistenceYAML, tokens, @[])

set_default_value(SubstitutionYAML, nonword, false)

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
                            scope: "",
                            either: init_table[string, string]())

proc new(t: typedesc[DefinitionYAML]): DefinitionYAML =
   result = DefinitionYAML(extends: "occurrence",
                           message: "",
                           level: "",
                           ignorecase: false,
                           scope: "",
                           definition: "",
                           declaration: "",
                           exceptions: @[])

proc new(t: typedesc[Rules]): Rules =
   result = (existence: ExistenceYAML.new(),
             substitution: SubstitutionYAML.new(),
             occurrence: OccurrenceYAML.new(),
             repetition: RepetitionYAML.new(),
             consistency: ConsistencyYAML.new(),
             definition: DefinitionYAML.new())


template validate_extension_point(data: typed, ext: string, filename: string) =
   if not (to_lower_ascii(data.extends) == ext):
      log.error("Invalid extension point '$#' specified in file '$#'.",
                data.extends, filename)
      raise new_exception(RuleValueError,
                          format("Invalid extension point '$#' specified in " &
                                 "file '$#'.", data.extends, filename))


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

   result.add(RuleExistence.new(level, message, filename, token_str,
                                ignore_case))


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

   result.add(RuleSubstitution.new(level, message, filename, key_str,
                                   subst_table, ignore_case))


proc parse_rule(data: OccurrenceYAML, filename: string): seq[Rule] =
   ## Parse and validate YAML data for the rule 'occurrence' and return a
   ## sequence of RuleOccurrence objects.
   result = @[]

   validate_extension_point(data, "occurrence", filename)
   validate_common(data, filename, message, ignore_case, level)
   validate_scope(data, filename, scope)
   validate_limit(data, filename, limit, limit_kind)

   result.add(RuleOccurrence.new(level, message, filename, data.token,
                                 limit, limit_kind, scope, ignore_case))


proc parse_rule(data: RepetitionYAML, filename: string): seq[Rule] =
   ## Parse and validate YAML data for the rule 'repetition' and return a
   ## sequence of RuleRepetition objects.
   result = @[]

   validate_extension_point(data, "repetition", filename)
   validate_common(data, filename, message, ignore_case, level)
   validate_scope(data, filename, scope)

   result.add(RuleRepetition.new(level, message, filename, data.token,
                                 scope, ignore_case))


proc parse_rule(data: ConsistencyYAML, filename: string): seq[Rule] =
   ## Parse and validate YAML data for the rule 'consistency' and return a
   ## sequence of RuleConsistency objects.
   result = @[]

   validate_extension_point(data, "consistency", filename)
   validate_common(data, filename, message, ignore_case, level)
   validate_scope(data, filename, scope)

   for first, second in pairs(data.either):
      result.add(RuleConsistency.new(level, message, filename, first, second,
                                     scope, ignore_case))


proc parse_rule(data: DefinitionYAML, filename: string): seq[Rule] =
   ## Parse and validate YAML data for the rule 'definition' and return a
   ## sequence of RuleDefinition objects.
   result = @[]

   validate_extension_point(data, "definition", filename)
   validate_common(data, filename, message, ignore_case, level)
   validate_scope(data, filename, scope)
   validate_nof_capture_groups(data.declaration, filename, "declaration", 1)
   validate_nof_capture_groups(data.definition, filename, "definition", 1)

   result.add(RuleDefinition.new(level, message, filename, data.definition,
                                 data.declaration, data.exceptions, scope,
                                 ignore_case))


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
      log.error("Parse error in file '$#'. Either it's not a valid YAML " &
                "file or it doesn't specify the required fields for the " &
                "extension point. Skipping for now.", filename)
      raise new_exception(RuleParseError, "Parse error in file '" &
                                          filename & "'")


proc parse_rule_dir*(rule_root_dir: string): seq[Rule] =
   if not os.dir_exists(rule_root_dir):
      log.error("Invalid path '$#'", rule_root_dir)
      raise new_exception(RulePathError, "'" & rule_root_dir &
                                         "' is not a valid path")

   result = @[]

   for path in walk_dir_rec(rule_root_dir):
   # for kind, path in walk_dir(rule_root_dir):
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
