import yaml.serialization
import streams
import tables
import typetraits
import strutils

import rules
import ../utils/log

type
   RuleValueError = object of Exception
   RuleNotImplementedError = object of Exception
   RuleParseError = object of Exception
   RulePathError = object of Exception

type
   RuleYAML = object of RootObj

   ExistenceYAML = object of RuleYAML
      extends: string
      message: string
      ignorecase: bool
      level: string
      tokens: seq[string]

   SubstitutionYAML = object of RuleYAML
      extends: string
      message: string
      ignorecase: bool
      level: string
      swap: Table[string, string]

   OccurrenceYAML = object of RuleYAML
      extends: string
      message: string
      ignorecase: bool
      level: string
      scope: string
      limit: int
      limit_kind: string
      token: string

   ConsistencyYAML = object of RuleYAML
      extends: string
      message: string
      ignorecase: bool
      level: string
      scope: string
      either: Table[string, string]

   DefinitionYAML = object of RuleYAML
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


method parse_rule(data: RuleYAML, filename: string): Rule {.base.} =
   raise new_exception(RuleNotImplementedError,
                       "Called unimplemented base function.")


method parse_rule(data: ExistenceYAML, filename:string): Rule =
   ## Parse and validate YAML data for the rule 'existence' and return a
   ## RuleExistence object.
   if not (data.extends == "existence"):
      log.error("Stuff") # TODO: Better error message
      raise new_exception(RuleValueError, "Stuff")

   validate_common(data, filename, message, ignore_case, level)

   var token_str = r"\b(" & data.tokens[0]
   for i in 1..<data.tokens.len:
      token_str &= "|" & data.tokens[i]
   token_str &= r")\b"

   result = RuleExistence.new(level, message, filename, token_str, ignore_case)


proc parse_rule_file(filename: string): seq[Rule] =
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
         discard parse_rule(f, filename)
         success = true
      except YamlConstructionError:
         discard

      if success:
         echo "Successfully parsed '", filename, "' with type '", f.type.name, "'"
         echo f
         break
      else:
         fs.set_position(0)

   fs.close()

   if not success:
      raise new_exception(RuleParseError, "Parse error in file '" & filename & "'")

try:
   # discard parse_rule_file("Editorializing.yml")
   discard parse_rule_file("Editorializing.yml")
except RuleValueError:
   discard
except RuleParseError:
   discard
except RulePathError:
   discard
