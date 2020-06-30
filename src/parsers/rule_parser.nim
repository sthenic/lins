import yaml/serialization
import yaml/parser
import streams
import tables
import typetraits
import strutils
import strformat
import os
import nre
import terminal

import ../rules/rules
import ../utils/log
import ../utils/cli
import ../utils/configuration

type
   RuleValueError = object of ValueError
   RuleParseError = object of ValueError
   RulePathError* = object of ValueError

type
   Mode = enum
      NonRecursive
      Recursive

   Database = tuple
      rules: Table[string, seq[Rule]]
      styles: Table[string, seq[Rule]]

type
   ExistenceYAML = object
      extends: string
      message: string
      level: string
      ignorecase {.defaultVal: false.}: bool
      nonword {.defaultVal: false.}: bool
      raw {.defaultVal: @[].}: seq[string]
      tokens {.defaultVal: @[].}: seq[string]
      debug {.defaultVal: false.}: bool
      scope {.defaultVal: @[].}: seq[string]
      latex {.defaultVal: @[].}: seq[Table[string, string]]
      linter {.defaultVal: @[].}: seq[string]
      exceptions {.defaultVal: @[].}: seq[string]

   SubstitutionYAML = object
      extends: string
      message: string
      level: string
      ignorecase {.defaultVal: false.}: bool
      nonword {.defaultVal: false.}: bool
      swap: Table[string, string]
      debug {.defaultVal: false.}: bool
      scope {.defaultVal: @[].}: seq[string]
      latex {.defaultVal: @[].}: seq[Table[string, string]]
      linter {.defaultVal: @[].}: seq[string]
      exceptions {.defaultVal: @[].}: seq[string]

   OccurrenceYAML = object
      extends: string
      message: string
      level: string
      ignorecase {.defaultVal: false.}: bool
      limit: int
      limit_kind: string
      token: string
      debug {.defaultVal: false.}: bool
      scope {.defaultVal: @[].}: seq[string]
      latex {.defaultVal: @[].}: seq[Table[string, string]]
      linter {.defaultVal: @[].}: seq[string]
      exceptions {.defaultVal: @[].}: seq[string]

   RepetitionYAML = object
      extends: string
      message: string
      level: string
      ignorecase {.defaultVal: false.}: bool
      token: string
      debug {.defaultVal: false.}: bool
      scope {.defaultVal: @[].}: seq[string]
      latex {.defaultVal: @[].}: seq[Table[string, string]]
      linter {.defaultVal: @[].}: seq[string]
      exceptions {.defaultVal: @[].}: seq[string]

   ConsistencyYAML = object
      extends: string
      message: string
      level: string
      ignorecase {.defaultVal: false.}: bool
      nonword {.defaultVal: false.}: bool
      either: Table[string, string]
      debug {.defaultVal: false.}: bool
      scope {.defaultVal: @[].}: seq[string]
      latex {.defaultVal: @[].}: seq[Table[string, string]]
      linter {.defaultVal: @[].}: seq[string]
      exceptions {.defaultVal: @[].}: seq[string]

   DefinitionYAML = object
      extends: string
      message: string
      level: string
      ignorecase {.defaultVal: false.}: bool
      definition {.defaultVal: r"(?:\b[A-Z][a-z]+ )+\(([A-Z]{3,5})\)".}: string
      declaration {.defaultVal: r"\b([A-Z]{3,5})\b".}: string
      debug {.defaultVal: false.}: bool
      scope {.defaultVal: @[].}: seq[string]
      latex {.defaultVal: @[].}: seq[Table[string, string]]
      linter {.defaultVal: @[].}: seq[string]
      exceptions {.defaultVal: @[].}: seq[string]

   ConditionalYAML = object
      extends: string
      message: string
      level: string
      ignorecase {.defaultVal: false.}: bool
      first: string
      second: string
      debug {.defaultVal: false.}: bool
      scope {.defaultVal: @[].}: seq[string]
      latex {.defaultVal: @[].}: seq[Table[string, string]]
      linter {.defaultVal: @[].}: seq[string]
      exceptions {.defaultVal: @[].}: seq[string]

   Rules = tuple
      existence: ExistenceYAML
      substitution: SubstitutionYAML
      occurrence: OccurrenceYAML
      repetition: RepetitionYAML
      consistency: ConsistencyYAML
      definition: DefinitionYAML
      conditional: ConditionalYAML

# set_default_value(ExistenceYAML, latex, @[])
# set_default_value(SubstitutionYAML, latex, @[])
# set_default_value(OccurrenceYAML, latex, @[])
# set_default_value(RepetitionYAML, latex, @[])
# set_default_value(ConsistencyYAML, latex, @[])
# set_default_value(DefinitionYAML, latex, @[])
# set_default_value(ConditionalYAML, latex, @[])

# set_default_value(ExistenceYAML, scope, @[])
# set_default_value(SubstitutionYAML, scope, @[])
# set_default_value(OccurrenceYAML, scope, @[])
# set_default_value(RepetitionYAML, scope, @[])
# set_default_value(ConsistencyYAML, scope, @[])
# set_default_value(DefinitionYAML, scope, @[])
# set_default_value(ConditionalYAML, scope, @[])

# set_default_value(ExistenceYAML, linter, @[])
# set_default_value(SubstitutionYAML, linter, @[])
# set_default_value(OccurrenceYAML, linter, @[])
# set_default_value(RepetitionYAML, linter, @[])
# set_default_value(ConsistencyYAML, linter, @[])
# set_default_value(DefinitionYAML, linter, @[])
# set_default_value(ConditionalYAML, linter, @[])

# set_default_value(ExistenceYAML, exceptions, @[])
# set_default_value(SubstitutionYAML, exceptions, @[])
# set_default_value(OccurrenceYAML, exceptions, @[])
# set_default_value(RepetitionYAML, exceptions, @[])
# set_default_value(ConsistencyYAML, exceptions, @[])
# set_default_value(DefinitionYAML, exceptions, @[])
# set_default_value(ConditionalYAML, exceptions, @[])


proc new(t: typedesc[ExistenceYAML]): ExistenceYAML =
   result = ExistenceYAML(extends: "existence")


proc new(t: typedesc[SubstitutionYAML]): SubstitutionYAML =
   result = SubstitutionYAML(extends: "substitution",
                             swap: init_table[string, string]())


proc new(t: typedesc[OccurrenceYAML]): OccurrenceYAML =
   result = OccurrenceYAML(extends: "occurrence")


proc new(t: typedesc[RepetitionYAML]): RepetitionYAML =
   result = RepetitionYAML(extends: "repetition")


proc new(t: typedesc[ConsistencyYAML]): ConsistencyYAML =
   result = ConsistencyYAML(extends: "consistency",
                            either: init_table[string, string]())


proc new(t: typedesc[DefinitionYAML]): DefinitionYAML =
   result = DefinitionYAML(extends: "definition")


proc new(t: typedesc[ConditionalYAML]): ConditionalYAML =
   result = ConditionalYAML(extends: "conditional")


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
                "Invalid extension point '$1' specified in file '$2'.",
                data.extends, filename)


template validate_common(data: typed, filename: string, message: untyped,
                         ignore_case: untyped, level: untyped,
                         exceptions: untyped) =
   ## Validate common rule parameters
   var message: string = data.message
   var ignore_case: bool = data.ignore_case
   var level: Severity

   case to_lower_ascii(data.level)
   of "suggestion":
      level = Severity.SUGGESTION
   of "warning":
      level = Severity.WARNING
   of "error":
      level = Severity.ERROR
   else:
      log.warning("Unsupported severity level '$1' defined for rule in " &
                  "file '$2', skipping.", data.level, filename)
      raise new_exception(RuleValueError, "Unsupported severity level in " &
                                          "file '" & filename & "'")

   var exceptions = ""
   if len(data.exceptions) > 0:
      add(exceptions, "(")
      for i, str in data.exceptions:
         if i > 0:
            add(exceptions, "|")
         add(exceptions, str)
      add(exceptions, ")")


template validate_latex_section(data: typed, filename: string,
                                latex_section: untyped) =
   ## Validate LaTeX block in rule files.
   var latex_section: LaTeXRuleSection

   # Process LaTeX section.
   for raw_entry in data.latex:
      var entry: LaTeXScopeEntry
      entry.descend = true
      # In order to provide helpful error messages we should walk through all
      # the properties and check the keys we come across.
      for prop, val in pairs(raw_entry):
         case to_lower_ascii(prop):
         of "name":
            entry.name = val
         of "type":
            case to_lower_ascii(val):
            of "environment":
               entry.kind = ScopeKind.Environment
            of "control sequence":
               entry.kind = ScopeKind.ControlSequence
            of "comment":
               entry.kind = ScopeKind.Comment
            else:
               log.warning("Unsupported scope property value '$1' defined " &
                           "for rule in file '$2', skipping.", val, filename)
               raise new_exception(RuleValueError, "")
         of "leading":
            entry.leading = val
         of "logic":
            case to_lower_ascii(val):
            of "and":
               entry.logic = AND
            of "or":
               entry.logic = OR
            of "not":
               entry.logic = NOT
            else:
               log.warning("Unsupported scope property value '$1' defined " &
                           "for rule in file '$2', skipping.", val, filename)
               raise new_exception(RuleValueError, "")
         of "descend":
            try:
               entry.descend = parse_bool(val)
            except ValueError:
               log.warning("Invalid value '$1'.", val)
               raise new_exception(RuleValueError, "")
         else:
            log.warning("Unsupported scope property '$1' defined for rule " &
                        "in file '$2', skipping.", prop, filename)
            raise new_exception(RuleValueError, "")

      # Check required fields.
      if len(entry.name) == 0:
         log.warning("Required field 'name' not defined for LaTeX scope " &
                     "entry in file '$1', skipping.", filename)
         raise new_exception(RuleValueError, "")
      add(latex_section.scope, entry)

   # Process regular scope section searching for shorthand definitions.
   for raw_entry in data.scope:
      case to_lower_ascii(raw_entry):
      of "text":
         add(latex_section.scope, new_latex_scope_entry("document", ScopeKind.Environment, "", OR, true))
      of "comment":
         add(latex_section.scope, new_latex_scope_entry("", ScopeKind.Comment, "", OR, true))
      of "math":
         add(latex_section.scope, new_latex_scope_entry("", ScopeKind.Math, "", OR, true))
         add(latex_section.scope, new_latex_scope_entry("equation", ScopeKind.Environment, "", OR, true))
         add(latex_section.scope, new_latex_scope_entry("equation*", ScopeKind.Environment, "", OR, true))
      of "title":
         add(latex_section.scope, new_latex_scope_entry("section", ScopeKind.ControlSequence, "", OR, true))
         add(latex_section.scope, new_latex_scope_entry("subsection", ScopeKind.ControlSequence, "", OR, true))
         add(latex_section.scope, new_latex_scope_entry("subsubsection", ScopeKind.ControlSequence, "", OR, true))
      else:
         discard


template check_plain_scope_redefinition(plain: PlainRuleSection,
                                        filename: string) =
   if plain.scope != INVALID:
      log.warning("Redefining the rule scope for plain text files in " &
                  "file '$1'.", filename)


template validate_plain_section(data: typed, filename: string, plain: untyped) =
   ## Validate plain block in rule files.
   var plain: PlainRuleSection

   for entry in data.scope:
      case to_lower_ascii(entry)
      of "text":
         check_plain_scope_redefinition(plain, filename)
         plain.scope = TEXT
      of "paragraph":
         check_plain_scope_redefinition(plain, filename)
         plain.scope = PARAGRAPH
      else:
         # There may be other entries but those are ignored by the plain text
         # section.
         discard

   # Default to text wide scope.
   if plain.scope == INVALID:
      plain.scope = TEXT


template validate_linter_kind(data: typed, filename: string, linter_kind: untyped) =
   ## Validate linter block in rule files.
   var linter_kind: LinterKind

   for entry in data.linter:
      case to_lower_ascii(entry)
      of "plain":
         linter_kind = LinterKind.PLAIN
      of "latex":
         linter_kind = LinterKind.LATEX
      else:
         log.warning("Unsupported linter '$1' defined for rule in file " &
                     "'$2', skipping.", entry, filename)
         raise new_exception(RuleValueError, "")


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
      log.warning("Unsupported limit kind '$1' defined for rule in file " &
                  "'$2', skipping.", data.limit_kind, filename)
      raise new_exception(RuleValueError, "Unsupported limit kind in file '" &
                                          filename & "'")


template validate_nof_capture_groups(regex: string, filename: string,
                                     label: string, nof_capture_groups: int) =
   var tmp = "group"
   if nof_capture_groups > 1:
      tmp &= "s"
   let cc = capture_count(re(regex))
   if not (cc == nof_capture_groups):
      log.warning("The regular expression defined for field '$1' in file " &
                  "'$2' is expected to have exactly $3 capture $4, not $5. " &
                  "Skipping the file.",
                  label, filename, $nof_capture_groups, tmp, $cc)
      raise new_exception(RuleValueError, "Expected " & $nof_capture_groups &
                                          " capture " & tmp & ".")


proc get_rule_display_name(rule_filename: string): string =
   var (dir, name, _) = split_file(rule_filename)
   if name == "":
      log.abort(RulePathError,
                "Attempted to get short name for an invalid path '$1'.",
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
      log.debug_always("Debug information for rule '$1'.", filename)


template debug_latex_section(latex_section: LaTeXRuleSection) =
   for entry in latex_section.scope:
      log.debug_always("LaTeX scope entry:")
      log.debug_always("  name: '$1'", entry.name)
      log.debug_always("  kind: '$1'", $entry.kind)
      log.debug_always("  leading: '$1'", entry.leading)
      log.debug_always("  logic: $1", $entry.logic)


template debug_existence(data: typed, filename, token_str: string,
                         latex_section: LaTeXRuleSection) =
   debug_header(data, filename)
   if data.debug:
      log.debug_always("  $1", token_str)
      debug_latex_section(latex_section)


template debug_substitution(data: typed, filename, key_str: string,
                            latex_section: LaTeXRuleSection) =
   debug_header(data, filename)
   if data.debug:
      log.debug_always("  $1", key_str)
      debug_latex_section(latex_section)


template debug_occurrence(data: typed, filename: string,
                          latex_section: LaTeXRuleSection) =
   debug_header(data, filename)
   if data.debug:
      log.debug_always("  $1", data.token)
      debug_latex_section(latex_section)


template debug_repetition(data: typed, filename: string,
                          latex_section: LaTeXRuleSection) =
   debug_header(data, filename)
   if data.debug:
      log.debug_always("  $1", data.token)
      debug_latex_section(latex_section)


template debug_consistency_entry(data: typed, first, second: string,
                                 latex_section: LaTeXRuleSection) =
   if data.debug:
      log.debug_always("  First:  $1", first)
      log.debug_always("  Second: $1", second)
      debug_latex_section(latex_section)


template debug_definition(data: typed, filename: string,
                          latex_section: LaTeXRuleSection) =
   debug_header(data, filename)
   if data.debug:
      log.debug_always("  Definition:  $1", data.definition)
      log.debug_always("  Declaration: $1", data.declaration)
      debug_latex_section(latex_section)


template debug_conditional(data: typed, filename: string,
                           latex_section: LaTeXRuleSection) =
   debug_header(data, filename)
   if data.debug:
      log.debug_always("  First:  $1", data.first)
      log.debug_always("  Second: $1", data.second)
      debug_latex_section(latex_section)


proc parse_rule(data: ExistenceYAML, filename: string): Rule =
   ## Parse and validate YAML data for the rule 'existence' and return a
   ## sequence of RuleExistence objects.
   validate_extension_point(data, "existence", filename)
   validate_common(data, filename, message, ignore_case, level, exceptions)
   validate_plain_section(data, filename, plain_section)
   validate_latex_section(data, filename, latex_section)
   validate_linter_kind(data, filename, linter_kind)

   var word_boundary: string
   if data.nonword:
      word_boundary = ""
   else:
      word_boundary = r"\b"

   var token_str = ""
   var raw_is_defined = false
   var tokens_are_defined = false

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
                  "'$1', skipping.", filename)
      raise new_exception(RuleParseError,
                          format("Missing either tokens or raw items for " &
                                 "rule in file '$1'.", filename))

   debug_existence(data, filename, token_str, latex_section)

   let display_name = get_rule_display_name(filename)
   result = new_existence_rule(level, message, filename, display_name,
                               ignore_case, plain_section,
                               latex_section, linter_kind, token_str, exceptions)


proc parse_rule(data: SubstitutionYAML, filename: string): Rule =
   ## Parse and validate YAML data for the rule 'substitution' and return a
   ## sequence of RuleSubstitution objects.
   validate_extension_point(data, "substitution", filename)
   validate_common(data, filename, message, ignore_case, level, exceptions)
   validate_plain_section(data, filename, plain_section)
   validate_latex_section(data, filename, latex_section)
   validate_linter_kind(data, filename, linter_kind)

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
         log.warning("Empty substitution for key '$1' in file '$2'.",
                     key, filename)
      subst_table[key] = subst
   key_str = key_str[0..^2] & ")" & word_boundary

   debug_substitution(data, filename, key_str, latex_section)

   let display_name = get_rule_display_name(filename)
   result = new_substitution_rule(level, message, filename, display_name,
                                  ignore_case,
                                  plain_section, latex_section, linter_kind,
                                  key_str, exceptions, subst_table)


proc parse_rule(data: OccurrenceYAML, filename: string): Rule =
   ## Parse and validate YAML data for the rule 'occurrence' and return a
   ## sequence of RuleOccurrence objects.
   validate_extension_point(data, "occurrence", filename)
   validate_common(data, filename, message, ignore_case, level, exceptions)
   validate_latex_section(data, filename, latex_section)
   validate_plain_section(data, filename, plain_section)
   validate_limit(data, filename, limit, limit_kind)
   validate_linter_kind(data, filename, linter_kind)

   debug_occurrence(data, filename, latex_section)

   let display_name = get_rule_display_name(filename)
   result = new_occurrence_rule(level, message, filename, display_name,
                                ignore_case,
                                plain_section, latex_section, linter_kind,
                                data.token, exceptions, limit, limit_kind)


proc parse_rule(data: RepetitionYAML, filename: string): Rule =
   ## Parse and validate YAML data for the rule 'repetition' and return a
   ## sequence of RuleRepetition objects.
   validate_extension_point(data, "repetition", filename)
   validate_common(data, filename, message, ignore_case, level, exceptions)
   validate_plain_section(data, filename, plain_section)
   validate_latex_section(data, filename, latex_section)
   validate_linter_kind(data, filename, linter_kind)

   debug_repetition(data, filename, latex_section)

   let display_name = get_rule_display_name(filename)
   result = new_repetition_rule(level, message, filename, display_name,
                                ignore_case, plain_section,
                                latex_section, linter_kind,
                                data.token, exceptions)


proc parse_rule(data: ConsistencyYAML, filename: string): Rule =
   ## Parse and validate YAML data for the rule 'consistency' and return a
   ## sequence of RuleConsistency objects.
   validate_extension_point(data, "consistency", filename)
   validate_common(data, filename, message, ignore_case, level, exceptions)
   validate_plain_section(data, filename, plain_section)
   validate_latex_section(data, filename, latex_section)
   validate_linter_kind(data, filename, linter_kind)

   if len(exceptions) > 0:
      log.warning("Exceptions are not yet supported for rules of type " &
                  "'Consistency' in file '$1'.", filename)


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

      debug_consistency_entry(data, lfirst, lsecond, latex_section)

      result = new_consistency_rule(level, message, filename, display_name,
                                    ignore_case,
                                    plain_section, latex_section, linter_kind,
                                    lfirst, lsecond, exceptions)


proc parse_rule(data: DefinitionYAML, filename: string): Rule =
   ## Parse and validate YAML data for the rule 'definition' and return a
   ## sequence of RuleDefinition objects.
   validate_extension_point(data, "definition", filename)
   validate_common(data, filename, message, ignore_case, level, exceptions)
   validate_plain_section(data, filename, plain_section)
   validate_latex_section(data, filename, latex_section)
   validate_linter_kind(data, filename, linter_kind)
   validate_nof_capture_groups(data.declaration, filename, "declaration", 1)
   validate_nof_capture_groups(data.definition, filename, "definition", 1)

   debug_definition(data, filename, latex_section)

   let display_name = get_rule_display_name(filename)
   result = new_definition_rule(level, message, filename, display_name,
                                ignore_case,
                                plain_section, latex_section, linter_kind,
                                data.definition, data.declaration, exceptions)


proc parse_rule(data: ConditionalYAML, filename: string): Rule =
   ## Parse and validate YAML data for the rule 'definition' and return a
   ## sequence of RuleDefinition objects.
   validate_extension_point(data, "conditional", filename)
   validate_common(data, filename, message, ignore_case, level, exceptions)
   validate_plain_section(data, filename, plain_section)
   validate_latex_section(data, filename, latex_section)
   validate_linter_kind(data, filename, linter_kind)
   validate_nof_capture_groups(data.first, filename, "first", 1)
   validate_nof_capture_groups(data.second, filename, "second", 1)

   if len(exceptions) > 0:
      log.warning("Exceptions are not yet supported for rules of type " &
                  "'Conditional' in file '$1'.", filename)

   debug_conditional(data, filename, latex_section)

   let display_name = get_rule_display_name(filename)
   result = new_conditional_rule(level, message, filename, display_name,
                                 ignore_case,
                                 plain_section, latex_section, linter_kind,
                                 data.first, data.second, exceptions)


proc parse_rule_file*(filename: string): Rule =
   ##  Parse a YAML-formatted rule file and return a list of rule objects.
   ##
   ##  This function raises RuleValueError when a field has an unexpected or an
   ##  unsupported value.
   var fs: FileStream
   var success = false
   var data = Rules.new()

   # Open the stream
   fs = new_file_stream(filename)
   if is_nil(fs):
      log.warning("Rule file '$1' is not a valid path, skipping.", filename)
      raise new_exception(RulePathError, "Rule file '" & filename &
                                         "' is not a valid path, skipping.")

   for f in data.fields:
      try:
         # Work around NimYAML crashing when an empty file is loaded.
         if len(read_file(filename)) == 0:
            log.warning("Rule file '$1' is empty, skipping.", filename)
            raise new_exception(RuleParseError, "Rule file '" & filename &
                                "' is empty, skipping.")
         load(fs, f)
         result = parse_rule(f, filename)
         success = true
         break
      except YamlConstructionError, YamlParserError:
         fs.set_position(0)

   fs.close()

   if not success:
      log.abort(RuleParseError,
                "Parse error in file '$1'. Either it's not a valid YAML " &
                "file or it doesn't specify the required fields for the " &
                "extension point. Skipping for now.", filename)


proc parse_rule_string*(s: string): Rule =
   ##  Parse a YAML-formatted rule specification from the input string.
   ##
   ##  This function raises RuleValueError when a field has an unexpected or an
   ##  unsupported value.
   var success = false
   var data = Rules.new()

   # Open the stream
   for f in data.fields:
      try:
         load(s, f)
         result = parse_rule(f, "string input")
         success = true
         break
      except YamlConstructionError, YamlParserError:
         discard

   if not success:
      log.abort(RuleParseError,
                "Parse error in input string. Either it's not a valid YAML " &
                "file or it doesn't specify the required fields for the " &
                "extension point.")


proc parse_rule_dir(rule_root_dir: string, mode: Mode): seq[Rule] =
   if not os.dir_exists(rule_root_dir):
      log.abort(RulePathError, "Invalid path '$1'.", rule_root_dir)

   case mode
   of NonRecursive:
      for kind, path in walk_dir(rule_root_dir):
         # Skip directories.
         if (kind == pcDir) or (kind == pcLinkToDir):
            continue

         let (_, _, ext) = split_file(path)

         if not (ext == ".yml"):
            continue

         try:
            add(result, parse_rule_file(path))
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
            add(result, parse_rule_file(path))
         except RuleValueError:
            discard
         except RuleParseError:
            discard
         except RulePathError:
            discard


proc build_databases(cfg_state: CfgState): Database =
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


proc get_rules*(cfg_state: CfgState, cli_state: CliState): seq[Rule] =
   ## Return a sequence of rules given the current configuration and CLI state.
   if cli_state.no_cfg:
      # TODO: Is this ok? You can't combine options --no-cfg with --rule-dir
      #       in order to overwrite the current configuration.
      return @[]

   # Build rule database and retrieve the name of the default style.
   var (rule_db, style_db) = build_databases(cfg_state)
   let default_style = get_default_style(cfg_state.styles)

   # Add rules from rule directories specified on the command line.
   if not (cli_state.rule_dirs == @[]):
      for dir in cli_state.rule_dirs:
         try:
            result.add(parse_rule_dir(expand_tilde(dir), NonRecursive))
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


proc list*(cfg_state: CfgState, cli_state: CliState) =
   # Temporarily suppress log messages.
   log.push_quiet_mode(true)

   # List styles.
   let (_, style_db) = build_databases(cfg_state)

   call_styled_write_line(styleBright, styleUnderscore, "Styles", resetStyle)

   for style_name, rules in style_db:
      call_styled_write_line(styleBright, &"  {style_name:<15}", resetStyle)
      call_styled_write_line("  └─ ", $len(rules), " rules")

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
