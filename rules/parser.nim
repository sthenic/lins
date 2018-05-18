import yaml.serialization
import streams
import tables
import typetraits

type
   RuleValueError = object of Exception
   RuleTypeError = object of Exception
   RuleParseError = object of Exception
   RulePathError = object of Exception

type
   ExistenceYAML = object of RootObj
      extends: string
      message: string
      ignorecase: bool
      level: string
      tokens: seq[string]

   SubstitutionYAML = object of RootObj
      extends: string
      message: string
      ignorecase: bool
      level: string
      swap: Table[string, string]

   OccurrenceYAML = object of RootObj
      extends: string
      message: string
      ignorecase: bool
      level: string
      scope: string
      limit: int
      limit_kind: string
      token: string

   ConsistencyYAML = object of RootObj
      extends: string
      message: string
      ignorecase: bool
      level: string
      scope: string
      either: Table[string, string]

   DefinitionYAML = object of RootObj
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

proc parse_rule_file(filename: string) =
   ##  Parse a YAML-formatted rule file and return a list of rule objects.
   ##
   ##  This function raises RuleValueError when a field has an unexpected or an
   ##  unsupported value.
   var
      # rule_objects: seq[RuleYAML] = @[]
      success = false
      data = Rules.new()

   # Open the stream
   var s = new_file_stream(filename)
   # Attempt to load as each rule object
   for f in data.fields:
      try:
         load(s, f)
         success = true
      except YamlConstructionError:
         echo "Unable to parse '", filename, "' with type '", f.type.name, "'"

      if success:
         echo "Successfully parsed '", filename, "' with type '", f.type.name, "'"
         echo f
         break
      else:
         s.set_position(0)

   # TODO: More robust file opening
   s.close()

   if not success:
      raise new_exception(RuleParseError, "Parse error in file '" & filename & "'")


try:
   parse_rule_file("suba.yml")
except RuleParseError as e:
   echo e.msg
