.. _`lins_rules`:

*****
Rules
*****

Rules are specified in *rule files* using `YAML`_. Each file may define one rule
at most. There are seven *rule types* which determine the general
characteristics of the performed check and any user-defined rule must be based
on one of these types.

.. note::

    A rule is *violated* if the condition it defines matches at any point in the
    linted text.

.. Something about regular expressions

.. _YAML: http://yaml.org/

.. _`rule_severity_levels`:

Severity Levels
===============

There are three severity levels: ``error``, ``warning`` and ``suggestion``. You
may set up a threshold to filter the output and suppress undesired violations
using the ``--severity`` option. By default, the threshold is set to
``suggestion`` which provides full output. If instead the severity is lowered to
``warning``, this would suppress suggestions but still display errors and
warnings.

.. _`rule_message_strings`:

Message Strings
===============

When a rule is violated, a *message* is displayed providing the user with
information about the matching text. The message string is defined in the rule
file together with the other parameters and may have *static* and *dynamic*
content. The dynamic content is controlled by *format specifiers* such as ``$1``
and ``$2``. These entries indicate where to insert the match's dynamic content.
Precisely what constitutes dynamic content depends on the rule type but a
common field is the matching text. Consider the following string,

.. code-block:: text

    Please remove '$1'.

If the parent rule matches the word 'foo', the message presented to the user
will be

.. code-block:: text

    Please remove 'foo'.

The remaining sections will demonstrate the use of message strings in the
context of each rule type.

.. note::

    Strings *without* quotation marks and strings enclosed in *single* quotation
    marks (``'``) are interpreted literally, i.e. ``\n`` will print the two
    characters ``\`` and ``n``. Strings enclosed in *double* quotation marks
    (``"``) will interpret the contents using escape sequences.

.. _`rule_existence`:

Existence
=========

The *existence* rule checks for the presence of any of its ``tokens`` and
reports a violation if there's a match in the linted text. The ``message``
string will be supplied the matching text as a replacement field.

.. code-block:: YAML

    extends: existence
    message: "Consider removing '$1'."
    ignorecase: true
    level: warning
    tokens:
    - foo
    - bar

The rule definition above translates to the regular expression
``(?i)\b(foo|bar)\b``, where ``\b`` indicates a *word boundary* and ``(?i)`` is
the *case insensitivity* modifier. The ``nonword`` field (boolean) may be
specified to instead match anywhere in the text.

The ``raw`` field may be used to gain access to the regular expression directly
whereby any listed item is prepended (in the order they appear) to the final
expression. Consider the following example which defines a rule to catch a few
uncomparables.

.. code-block:: YAML

    extends: existence
    message: "'$1' is not comparable."
    ignorecase: true
    level: error
    raw:
    - \b(?:most|more|less|least|very)\b\s*
    tokens:
    - absolute
    - adequate
    - complete
    - unique

Here, the resulting regular expression will be

.. code-block:: text

    (?i)\b(?:most|more|less|least|very)\b\s*\b(absolute|adequate|complete|unique)\b

which will catch occurrences of "very unique", "less complete" etc.

.. _`rule_substitution`:

Substitution
============

The *substitution* rule checks for the presence of any of the keys defined in
its key-value list ``swap`` and reports a violation if there's a match in the
linted text. The ``message`` string will be provided the *key* and *value* of
the matching ``swap`` entry as format specifiers ``$1`` and ``$2``,
respectively.

.. code-block:: YAML

    extends: substitution
    message: "Prefer '$2' over '$1'."
    ignorecase: true
    level: warning
    swap:
      catch on fire: catch fire
      '(cell phone|cell-phone)': cellphone

Keys are interpreted as regular expressions and *word boundaries* (``\b``) are
added unless the ``nonword`` field is set to ``true``. If the regular expression
defines multiple capture groups, the *first* group will be used for the message
replacement text. Non-capturing groups ``(?:`` may be used to modify the
behavior as needed.

Lastly, there is one additional feature to this rule: if the expression given as
the *key* matches text which is already equal to the substitution value, the
violation is ignored. This is needed to write compact key expressions which
sometimes cover the 'correct' case in addition to all error cases. For example,

.. code-block:: text

    swap:
      analog[ -]to[ -]digital: analog-to-digital

covers all the error combinations with one single regular expression, but also
covers the correct case. This feature prevents the latter from being reported as
a violation.

.. TODO: Revise last sentence, add an example.

.. _`rule_occurence`:

Occurence
=========

The *occurrence* rule enforces a requirement on the maximum/minimum number of
times a token may/should occur in a particular ``scope`` (``text``,
``paragraph`` or ``sentence``). The ``message`` string for this rule doesn't
accept a format specifier.

.. code-block:: YAML

    extends: occurrence
    message: "Sentences should have fewer than 25 words."
    level: suggestion
    ignorecase: true
    scope: sentence
    limit: 25
    limit_kind: max
    token: '\b(\w+)\b'

In the example above we define a rule that triggers for sentences with more than
25 words.

.. _`rule_repetition`:

Repetition
==========

The *repetition* rule checks for repetitions of its tokens. The tokens are
converted to lowercase if the ``ignorecase`` field is set to ``true``. In
contrast to the *occurrence* rule, this rule counts unique matches. That means
that while the token ``'\b(\w+)\b'`` will match both 'foo' and 'bar', a the rule
is not violated until 'foo' or 'bar' is repeated again in the target ``scope``.
The matching token is provided as input to the ``message`` string.

.. code-block:: YAML

    extends: repetition
    message: "'$1' is repeated."
    level: warning
    ignorecase: true
    scope: sentence
    token: '\b(\w+)\b'

.. _`rule_consistency`:

Consistency
===========

The *consistency* rule checks for occurrences of either the key or the value
specified as key-value pairs in its ``either`` list. For each pair, the earliest
match in the linted text is assumed to be the preferred version and occurrences
of its undesired counterpart will generate a rule violation. This rule also
accepts the ``scope`` field.

.. code-block:: YAML

    extends: consistency
    message: "Inconsistent spelling of '$1'."
    level: error
    ignorecase: true
    scope: text
    either:
      organize: organise
      recognize: recognise
      analog: analogue

The keys and values may be general regular expressions but unless the
``nonword`` field is set to ``true``, word boundary tokens ``\b`` are
automatically added to the expression.

We can generalize the example above as:

.. code-block:: YAML

    extends: consistency
    message: "Inconsistent spelling of '$1'."
    level: error
    ignorecase: true
    scope: text
    either:
      (?:\w+)nize: (?:\w+)nise
      (?:\w+)log: (?:\w+)logue

.. _`rule_definition`:

Definition
==========

The *definition* rule checks for definitions.


.. _`rule_conditional`:

Conditional
===========

The *conditional* rule checks that ``first`` occurs before ``second`` in the
given ``scope``. In the case of a violation, the match for ``second`` is
provided as input to the ``message`` string.

.. code-block:: YAML

    extends: conditional
    message: "'$1' found without finding 'foo'."
    level: warning
    ignorecase: true
    scope: text
    first: 'foo'
    second: '(bar|baz)'