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

.. _YAML: https://yaml.org/

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

If the rule matches the word 'foo', the message presented to the user will be

.. code-block:: text

    Please remove 'foo'.

The remaining sections will demonstrate the use of message strings in the
context of each rule type.

.. note::

    Strings *without* quotation marks and strings enclosed in *single* quotation
    marks (``'``) are interpreted literally, i.e. ``\n`` will print the two
    characters ``\`` and ``n``. Strings enclosed in *double* quotation marks
    (``"``) will interpret the contents using escape sequences.

.. _`rule_scope`:

Scopes
======

A rule may define a ``scope`` section to specify that the rule should only be
enforced in certain parts of the text. The section expects a list of scope
*identifiers* (as strings), and the available identifiers and their meaning
depends on the linter. Identifiers unknown to the active linter have no effect:

.. code-block:: YAML

    scope:
      - paragraph # Only used by the plain text linter.
      - comment # Only used by the LaTeX linter.

The sections below define the scope identifiers known to each linter.


Plain text
----------

+---------------+----------------------------------------------------+
|     Label     |                       Target                       |
+===============+====================================================+
| ``text``      | Entire document                                    |
+---------------+----------------------------------------------------+
| ``paragraph`` | Each paragraph                                     |
|               | (see the :ref:`occurrence <rule_occurrence>` rule) |
+---------------+----------------------------------------------------+

LaTeX
-----

There is a rule file :ref:`section <rule_latex>` specific to the LaTeX linter.
The identifiers in the table below can be considered shorthand for the more
general way of specifying scopes in a LaTeX document.

+-------------+-----------------------------------------------------------+
|    Label    |                          Target                           |
+=============+===========================================================+
| ``text``    | Text between ``\begin{document}`` and ``\end{document}``. |
+-------------+-----------------------------------------------------------+
| ``comment`` | Comments, i.e. text starting from the character ``%`` to  |
|             | the end of the line.                                      |
+-------------+-----------------------------------------------------------+
| ``math``    | Math environments:                                        |
|             |                                                           |
|             | - Inline math (``$`` or ``\(``, ``\)``)                   |
|             | - Displayed math (``$$`` or ``\[``, ``\]``)               |
|             | - The environments ``equation`` and ``equation*``         |
+-------------+-----------------------------------------------------------+
| ``title``   | Control sequences used to define section titles:          |
|             |                                                           |
|             | - ``\section``                                            |
|             | - ``\subsection``                                         |
|             | - ``\subsubsection``                                      |
+-------------+-----------------------------------------------------------+


.. _`rule_exception`:

Exceptions
==========

A rule may define an ``exceptions`` section, listing exceptions to the rule. The
section contents should be a list of strings and a minimum of one entry is
required. The list entries may be regular expressions.

.. code-block:: YAML

    exceptions:
      - this is fine
      - this too

Using a regular expression:

.. code-block:: YAML

    exceptions:
      - this (is fine|too)

If a rule matches at any point in the linted text, the match is checked against
the exceptions before a violation is generated.


.. _`rule_linter`:

Linter
======

A rule may define a ``linter`` section to specify that the rule should only be
enabled when the target linter is being used. Currently, there are two linters
available, identified as ``plain`` and ``latex``. The ``linter`` section accepts
a list of these identifiers. For example,

.. code-block:: YAML

    linter:
      - latex

would cause the rule to only be used by the LaTeX linter. Conversely,

.. code-block:: YAML

    linter:
      - plain

would only enable the rule when the plain text linter is used. By default, the
rule is used by all the linters.


.. _`rule_latex`:

LaTeX
=====

Each rule may define a ``latex`` section to specify in which context the rule
should be enforced when the LaTeX linter is used. The section consists of a list
of *scope entries* where each entry accepts the following fields:

+-------------+------------------------------------------------+----------+
|    Label    |                  Description                   | Default  |
+=============+================================================+==========+
| ``name``    | The name of the document element to match.     | N/A      |
|             | Cannot be a regular expression.                |          |
+-------------+------------------------------------------------+----------+
| ``type``    | The type of document element to match:         | N/A      |
|             | ``control sequence`` or ``environment``.       |          |
+-------------+------------------------------------------------+----------+
| ``leading`` | Regular expression with access to the *raw*    | An empty |
|             | text *leading* up to the scope entry           | string   |
|             | (see :ref:`contexts <linter_latex_context>`).  |          |
|             | This raw text is limited to 20 characters.     |          |
+-------------+------------------------------------------------+----------+
| ``descend`` | A scope entry where ``descend`` is             | ``true`` |
|             | ``false`` implies that the scope is not        |          |
|             | allowed to descend beyond this level.          |          |
|             |                                                |          |
|             | For example, we could define a rule saying     |          |
|             | that a ``\caption`` should contain more        |          |
|             | than five words. But unless we set             |          |
|             | ``descend`` to ``false`` for the               |          |
|             | ``\caption`` scope entry---the contents of     |          |
|             | any nested environments or control             |          |
|             | sequences would trigger the rule as well.      |          |
+-------------+------------------------------------------------+----------+
| ``logic``   | The ``logic`` field specifies how a scope      | ``or``   |
|             | entry interacts with the other entries in      |          |
|             | determining whether or not the rule should     |          |
|             | be enforced. Valid values are ``or``,          |          |
|             | ``and`` and ``not``.                           |          |
|             |                                                |          |
|             | Whether to enforce the rule or not is          |          |
|             | determined according to:                       |          |
|             |                                                |          |
|             | ``(O or A) and not N``                         |          |
|             |                                                |          |
|             | where                                          |          |
|             |                                                |          |
|             | - ``O`` represents all scope entries with      |          |
|             |   the ``or`` logic reduced to a single         |          |
|             |   truth value with the ``or`` operation.       |          |
|             | - ``A`` represents all scope entries with      |          |
|             |   the ``and`` logic reduced to a single        |          |
|             |   truth value with the ``and`` operation.      |          |
|             | - ``N`` represents all scope entries with      |          |
|             |   the ``not`` logic reduced to a single        |          |
|             |   truth value with the ``or`` operation.       |          |
|             |                                                |          |
|             | As a special case, if the list only            |          |
|             | consists of entries marked with ``not``,       |          |
|             | then ``(O or A)`` evaluates to ``true``.       |          |
+-------------+------------------------------------------------+----------+

.. note::

    Fields with default values are optional.

Let us look at an example:

.. code-block:: YAML

    latex:
      - name: foo
        type: control sequence
        leading: required\s$
      - name: bar
        type: environment
        logic: and
      - name: baz
        type: control sequence
        logic: and

The scope defined by the section above will enforce the rule for

- any text inside the ``\foo`` control sequence, provided it is preceded by the
  string "required" followed by a space character (note the ``$`` character
  anchoring the regular expression to the end of the text), i.e.

  .. code-block:: LaTeX

      Some introductory text is required \foo{to cause the rule to be
      enforced in here}{and here too} but \foo{the rule is not enforced
      in here}.

- any text inside *both* the ``bar`` environment and the ``baz`` control
  sequence, i.e.

  .. code-block:: LaTeX

      The rule will \baz{not be enforced here}
      \begin{bar}
      and not here either.
      \baz{However, this text will be targeted by the rule.}
      \end{bar}

.. note::

    Additional examples of rules specific to the LaTeX linter can be found
    :ref:`here <linter_latex_examples>`.


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


Inverting the Matching Logic
----------------------------

The ``invert`` field (``false`` by default) causes the matching logic to be
inverted if set to ``true``, i.e. if the text segment does *not* contain any of
the listed ``tokens``, a violation is generated.  One important detail is that
when ``invert`` is ``true``, the ``message`` is *not* provided any text to match
the replacement field ``$1``.

.. important::

    When ``invert`` is ``true``, the ``message`` is *not* provided any text to
    match the replacement field ``$1``.


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

.. _`rule_occurrence`:

Occurrence
==========

The *occurrence* rule enforces a requirement on the maximum/minimum number of
times a token may/should occur in a particular :ref:`scope <rule_scope>`. The
``message`` string for this rule doesn't accept a format specifier.

.. code-block:: YAML

    extends: occurrence
    message: "Don't use 'however' more than once in one paragraph."
    level: suggestion
    ignorecase: true
    scope:
      - paragraph
    limit: 1
    limit_kind: max
    token: '\bHowever\b'


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
    scope:
      - paragraph
    token: '\b(\w+)\b'

.. _`rule_consistency`:

Consistency
===========

The *consistency* rule checks for occurrences of either the key or the value
specified as key-value pairs in its ``either`` list. For each pair, the earliest
match in the linted text is assumed to be the preferred version and occurrences
of its undesired counterpart will generate a rule violation.

.. code-block:: YAML

    extends: consistency
    message: "Inconsistent spelling of '$1'."
    level: error
    ignorecase: true
    scope:
      - text
    either:
      organize: organise
      recognize: recognise
      analog: analogue

The keys and values may be general regular expressions but unless the
``nonword`` field is set to ``true``, word boundary tokens ``\b`` are added to
the expression. The ``message`` string will be supplied the matching text as a
replacement field.

We can generalize the example above as:

.. code-block:: YAML

    extends: consistency
    message: "Inconsistent spelling of '$1'."
    level: error
    ignorecase: true
    scope:
      - text
    either:
      (?:\w+)nize: (?:\w+)nise
      (?:\w+)log: (?:\w+)logue


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
    scope:
      - text
    first: 'foo'
    second: '(bar|baz)'


.. _`rule_definition`:

Definition
==========

Documentation coming soon.
