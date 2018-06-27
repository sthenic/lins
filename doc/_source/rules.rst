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

.. something about regular expressions

.. _YAML: http://yaml.org/

.. _`rule_severity_levels`:

Severity Levels
===============

There are three severity levels: ``error``, ``warning`` and ``suggestion``.

.. _`rule_existence`:

Existence
=========

The *existence* rule checks for the presence of any of its ``tokens`` and
reports a violation if there's a match in linted text. The ``message`` string
will be supplied the matching text as a replacement field.

.. code-block:: YAML

    extends: existence
    message: "Consider removing '$#'."
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
    message: "'$#' is not comparable."
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
linted text. The ``message`` string will be supplied the *key* and *value* of
the matching ``swap`` entry as replacement fields.

.. code-block:: YAML

    extends: substitution
    message: Prefer '$#' over '$#'.
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

.. TODO: Revise last sentence, add an example.

.. _`rule_occurence`:

Occurence
=========

.. _`rule_repetition`:

Repetition
==========

.. _`rule_consistency`:

Consistency
===========

.. _`rule_definition`:

Definition
==========

.. _`rule_conditional`:

Conditional
===========
