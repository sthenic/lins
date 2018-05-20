import yaml.serialization
import streams
import tables
import typetraits
import strutils
import sequtils
import os
import ospaths

import rules
import ../utils/log

type
   RuleValueError = object of Exception
   RuleParseError = object of Exception
   RulePathError = object of Exception

type
   ExistenceYAML = object
      extends: string
      message: string
      ignorecase: bool
      level: string
      tokens: seq[string]

   SubstitutionYAML = object
      extends: string
      message: string
      ignorecase: bool
      level: string
      swap: Table[string, string]

   OccurrenceYAML = object
      extends: string
      message: string
      ignorecase: bool
      level: string
      scope: string
      limit: int
      limit_kind: string
      token: string

   ConsistencyYAML = object
      extends: string
      message: string
      ignorecase: bool
      level: string
      scope: string
      either: Table[string, string]

   DefinitionYAML = object
      extends: string
      message: string
      ignorecase: bool
      level: string
      scope: string
      definition: string
      declaration: string
      exceptions: seq[string]

   Rules = tuple
      existence: ExistenceYAML
      substitution: SubstitutionYAML
      occurrence: OccurrenceYAML
      consistency: ConsistencyYAML
      definition: DefinitionYAML

# Default values for YAML objects
set_default_value(DefinitionYAML, definition,
                  r"(?:\b[A-Z][a-z]+ )+\(([A-Z]{3,5})\)")
set_default_value(DefinitionYAML, declaration, r"\b([A-Z]{3,5})\b")
set_default_value(DefinitionYAML, exceptions, @[])

proc new(t: typedesc[ExistenceYAML]): ExistenceYAML =
   result = ExistenceYAML(extends: "existence",
                          message: "",
                          ignorecase: false,
                          level: "warning",
                          tokens: @[])

proc new(t: typedesc[SubstitutionYAML]): SubstitutionYAML =
   result = SubstitutionYAML(extends: "substitution",
                             message: "",
                             ignorecase: false,
                             level: "warning",
                             swap: init_table[string, string]())

proc new(t: typedesc[OccurrenceYAML]): OccurrenceYAML =
   result = OccurrenceYAML(extends: "occurrence",
                           message: "",
                           ignorecase: false,
                           level: "warning",
                           scope: "",
                           limit: 0,
                           limit_kind: "",
                           token: "")

proc new(t: typedesc[ConsistencyYAML]): ConsistencyYAML =
   result = ConsistencyYAML(extends: "occurrence",
                            message: "",
                            ignorecase: false,
                            level: "warning",
                            scope: "",
                            either: init_table[string, string]())

proc new(t: typedesc[DefinitionYAML]): DefinitionYAML =
   result = DefinitionYAML(extends: "occurrence",
                           message: "",
                           ignorecase: false,
                           level: "warning",
                           scope: "",
                           definition: "",
                           declaration: "",
                           exceptions: @[])

proc new(t: typedesc[Rules]): Rules =
   result = (existence: ExistenceYAML.new(),
             substitution: SubstitutionYAML.new(),
             occurrence: OccurrenceYAML.new(),
             consistency: ConsistencyYAML.new(),
             definition: DefinitionYAML.new())

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
      raise new_exception(RuleValueError, "STUFF") # TODO


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
      raise new_exception(RuleValueError, "STUFF") # TODO


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
      raise new_exception(RuleValueError, "STUFF") # TODO


proc parse_rule(data: ExistenceYAML, filename: string): seq[Rule] =
   ## Parse and validate YAML data for the rule 'existence' and return a
   ## sequence of RuleExistence objects.
   result = @[]

   if not (data.extends == "existence"):
      log.error("Stuff") # TODO: Better error message
      raise new_exception(RuleValueError, "Stuff")

   validate_common(data, filename, message, ignore_case, level)

   var token_str = r"\b(" & data.tokens[0]
   for i in 1..<data.tokens.len:
      token_str &= "|" & data.tokens[i]
   token_str &= r")\b"

   result.add(RuleExistence.new(level, message, filename, token_str,
                                ignore_case))


proc parse_rule(data: SubstitutionYAML, filename: string): seq[Rule] =
   ## Parse and validate YAML data for the rule 'substitution' and return a
   ## sequence of RuleSubstitution objects.
   result = @[]

   if not (data.extends == "substitution"):
      log.error("Stuff") # TODO: Better error message
      raise new_exception(RuleValueError, "Stuff")

   validate_common(data, filename, message, ignore_case, level)

   var key_str = r"\b("
   var subst_table = init_table[string, string]()
   for key, subst in pairs(data.swap):
      key_str &= key & "|"
      if subst == "":
         log.warning("Empty substitution for key '$#' in file '$#'.",
                     key, filename)
      subst_table[key] = subst
   key_str = key_str[0..^2] & r")\b"

   result.add(RuleSubstitution.new(level, message, filename, key_str,
                                   subst_table, ignore_case))


proc parse_rule(data: OccurrenceYAML, filename: string): seq[Rule] =
   ## Parse and validate YAML data for the rule 'occurrence' and return a
   ## sequence of RuleOccurrence objects.
   result = @[]

   if not (data.extends == "occurrence"):
      log.error("Stuff") # TODO: Better error message
      raise new_exception(RuleValueError, "Stuff")

   validate_common(data, filename, message, ignore_case, level)
   validate_scope(data, filename, scope)
   validate_limit(data, filename, limit, limit_kind)

   result.add(RuleOccurrence.new(level, message, filename, data.token,
                                 limit, limit_kind, scope, ignore_case))


proc parse_rule(data: ConsistencyYAML, filename: string): seq[Rule] =
   ## Parse and validate YAML data for the rule 'consistency' and return a
   ## sequence of RuleConsistency objects.
   result = @[]

   if not (data.extends == "consistency"):
      log.error("Stuff") # TODO: Better error message
      raise new_exception(RuleValueError, "Stuff")

   validate_common(data, filename, message, ignore_case, level)
   validate_scope(data, filename, scope)

   for first, second in pairs(data.either):
      result.add(RuleConditional.new(level, message, filename, first, second,
                                     scope, ignore_case))


proc parse_rule(data: DefinitionYAML, filename: string): seq[Rule] =
   ## Parse and validate YAML data for the rule 'definition' and return a
   ## sequence of RuleDefinition objects.
   result = @[]

   if not (data.extends == "definition"):
      log.error("Stuff") # TODO: Better error message
      raise new_exception(RuleValueError, "Stuff")

   validate_common(data, filename, message, ignore_case, level)
   validate_scope(data, filename, scope)

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
      raise new_exception(RuleParseError, "Parse error in file '" & filename & "'")


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
