.. _`lins_linters`:

*******
Linters
*******

When Lins reads the input file, the text first passes through a parser tasked
with piecing together *segments* of text which are then passed on to the linting
stage. The linting stage enforces the rules defined by the user by seaching for
and reporting any violations in the set of text segments.

Currently, two different parsers---and by extension, two different linters---are
available:

- the :ref:`plain text linter <linter_plain_text>` (the default) and

- the :ref:`LaTeX linter <linter_latex>` (selected automatically for files with
  the ``.tex`` and ``.sty`` extensions).

.. note::

  You can manually select which linter to use with the ``--linter`` option.

.. TODO: Something about why Lins was created.


.. _`linter_plain_text`:

Plain text
==========

The plain text parser emits a text segment for each *paragraph*. Two consecutive
line breaks is interpreted as a paragraph break. For example, this text:

.. code-block:: text

  A Section Title
  ---------------

  Lorem ipsum dolor sit amet, consectetur adipiscing elit. Cras porta
  odio non efficitur pharetra. Phasellus venenatis accumsan quam, ut
  lacinia magna ornare iaculis.

  Integer porttitor vel dolor accumsan sodales. Etiam est sem,
  ullamcorper sit amet viverra eu, tempus sed nisi. Nulla scelerisque
  purus nunc. Sed consectetur nunc in est euismod, aliquet volutpat
  ante luctus. Nam feugiat quam a tortor ultricies tristique.

is split up into the following text segments:

.. code-block:: text

  A Section Title
  ---------------

.. code-block:: text

  Lorem ipsum dolor sit amet, consectetur adipiscing elit. Cras porta
  odio non efficitur pharetra. Phasellus venenatis accumsan quam, ut
  lacinia magna ornare iaculis.

.. code-block:: text

  Integer porttitor vel dolor accumsan sodales. Etiam est sem,
  ullamcorper sit amet viverra eu, tempus sed nisi. Nulla scelerisque
  purus nunc. Sed consectetur nunc in est euismod, aliquet volutpat
  ante luctus. Nam feugiat quam a tortor ultricies tristique.


.. _`linter_plain_text_scope`:

Scopes
------

Since a text segment corresponds to a paragraph, that becomes the granularity of
the plain text linter. Thus, two *scopes* are available:

- *text*---spanning the entire document and
- *paragraph*---spanning a paragraph.

Scopes are used when defining :ref:`rule files <lins_rules>`.


.. _`linter_latex`:

LaTeX
=====

The LaTeX parser follows the rules of the TeX language; identifying control
symbols, control words, comments and the text to be typeset. The parser does
*not* perform expansion or symbol lookup. However, control symbols *are*
replaced with the character that they would generate in the typeset text, i.e.
``\_`` inserts an underscore, ``\%`` a percent sign, ``\&`` an ampersand and so
on.

The stream of TeX tokens is later interpreted in the LaTeX sense, identifying
environments, option capture groups and special :ref:`font styling macros
<linter_latex_font_style>` like ``\emph``, ``\textbf`` etc.

Just like the plain text parser, the text in the target file is passed on to the
linting stage in segments. However, these segments---apart from containing only
the text that will be typset in the document---also contain meta information
such as the :ref:`scope <linter_latex_scope>` and the :ref:`context
<linter_latex_context>`.

The :ref:`linter_latex_examples` section breaks down a few real-world examples
and demonstrates how the parser works. Lins can be instructed to dump the parser
output with the ``--parser-output`` option.


.. _`linter_latex_font_style`:

Font Styling Macros
-------------------

The font styling macros defined by LaTeX such as ``\textbf`` and ``\emph`` are
handled differently from regular control sequences. Instead of triggering a new
segment and adding to the scope chain, the text within is expanded into the text
of the parent segment. This is done to allow rules to target expressions
consisting of more than one word where the author has decided to style one of
the words differently from the others. For example, say we want to warn the
author about the existence of "bad expression". This behavior results in

.. code-block:: LaTeX

    This is a sentence containing the \emph{bad} expression.

being emitted as one single segment with the complete sentence as the text to be
typeset, i.e. ``\emph`` is discarded---allowing the rule searching for "bad
expression" to trigger a violation.

The only exception to this behavior is ``\texttt`` which is *not* expanded into
the text of the parent segment. This is because of the assumption that this
particular font style is used for identifiers and do not tie in to the
surronding text in the same way. More importantly, this offers the ability to
create rules to target identifiers written in snake case or camel case,
triggering a warning that ``\texttt`` should be used to typeset this word.


.. _`linter_latex_scope`:

Scopes
------

Scopes play a key role in the LaTeX linter and can be leveraged by :ref:`rules
<lins_rules>` to great effect. The *scope* is defined as the chain of the
control sequences and environments enclosing the text segment. Each link in the
chain is a *scope entry*. For example,

.. code-block:: LaTeX

    \section{The Section Title}

would be emitted as a segment containing "The Section Title" as the text to be
typeset and ``section`` (control sequence) as the attached scope.

The same goes for environments,

.. code-block:: LaTeX

    \begin{foo}
    This is the first
    paragraph.

    This is the second paragraph.
    \end{foo}

would be emitted as two segments:

- one containing "This is the first paragraph." and
- one containing "This is the second paragraph.",

both with the scope: ``foo`` (environment). Segments are emitted when the
``\par`` token (which is implied by two newline characters) is processed *and*
when enclosures end. A single newline character inserts a space---all according
to the rules of TeX.


.. _`linter_latex_context`:

Context
#######

The *context* is a property attached to a scope entry. It holds 20 characters
from the *raw* text leading up to the start of the enclosure. For example, in

.. code-block:: LaTeX

    01234567890123456789\foo{Inside the foo control sequence.}

the context of the ``\foo`` scope entry would hold the characters
``01234567890123456789``. This feature may be used to define rules enforcing the
use of specific TeX source code before a particular control sequence. For
example, a rule requiring any reference macro like ``\ref`` or ``\eqref`` to be
preceded by the *tie* character ``~`` (non-breaking space) is straight-forward
to define using contexts.

.. code-block:: LaTeX

    This is a reference to Table \ref{tab:my_table}.

is emitted as two segments:

- one containing the text leading up to ``\ref`` (plus the last ``.`` character)
  and
- one containing the text "tab:my_table" where the scope entry for
  ``\ref`` has the context

  .. raw:: html

      <code>&nbsp;reference to Table&nbsp;</code>

Defining the rule discussed above involves just specifying ``(?<!~)$`` as the
value for the ``before`` field for a ``\ref`` scope entry in the :ref:`LaTeX
section <rule_latex>` of the rule file.


.. _`linter_latex_examples`:

Examples
--------

This section presents a few real-world examples of rules specific to the LaTeX
linter. Refer to the section on :ref:`rule files <lins_rules>` for documentation
of the syntax.

.. note::

    Many of these examples exists as rule files in the `rules/tex
    <https://github.com/sthenic/lins/tree/master/rules/tex>`_ directory in the
    source repository.

Check that a ``\ref`` contains a proper label prefix:

.. code-block:: YAML

    extends: existence
    message: "Unknown \\ref label prefix '$1'."
    ignorecase: true
    nonword: true
    level: error
    linter:
      - latex
    latex:
      - name: ref
        type: control sequence
    tokens:
      - ^(?!fig:|tab:|sec:|ch:|itm:|lst:|alg:|app:)\w+


Check that an ``\eqref`` contains a proper label prefix:

.. code-block:: YAML

    extends: existence
    message: "Unknown \\eqref label prefix '$1'."
    ignorecase: true
    nonword: true
    level: error
    linter:
      - latex
    latex:
      - name: eqref
        type: control sequence
    tokens:
      - ^(?!eq:)\w+


Check that ``\ref`` is not used to reference an equation:

.. code-block:: YAML

    extends: existence
    message: "Use \\eqref to reference equations."
    ignorecase: true
    nonword: true
    level: error
    linter:
      - latex
    latex:
      - name: ref
        type: control sequence
    tokens:
      - ^eq:\w+


Check that a ``\ref`` to a figure is preceded by ``Fig.`` or ``Figs.`` (IEEE
reference styling):

.. code-block:: YAML

    extends: existence
    message: "Use 'Fig.' or 'Figs.'."
    ignorecase: true
    nonword: true
    level: error
    linter:
      - latex
    latex:
      - name: ref
        type: control sequence
        before: (?<!Fig\.|Figs\.)~$
    tokens:
      - 'fig:'



Enforce the rule that a caption to, e.g. a figure or a table should end with a
full stop---making it more likely that the author writes a complete sentence:

.. code-block:: YAML

    extends: existence
    message: "A caption should end with a full stop '.'."
    ignorecase: true
    nonword: true
    level: error
    linter:
      - latex
    latex:
      - name: caption
        type: control sequence
        descend: false
    tokens:
      - (?<!\.)$

Enforce the rule that a caption should be longer than five words:

.. code-block:: YAML

    extends: existence
    message: "A caption should be a full sentence with more than five words."
    ignorecase: true
    nonword: true
    level: error
    linter:
      - latex
    latex:
      - name: caption
        type: control sequence
        before: (?<!\.)$
        descend: false
    tokens:
      - ^(\b\w+[.!?]?\s*){0,5}$

Warn the user when there are annotations left in the document source code:

.. code-block:: YAML

    message: "'$1' left in text."
    extends: existence
    ignorecase: false
    nonword: true
    level: warning
    scope:
      - comment
    tokens:
      - FIXME
      - TODO
      - NOTE

Enforce typographically correct quotation marks (single):

.. code-block:: YAML

    extends: existence
    message: "Unexpected quotation mark, consider using `$1' or using an emphasis macro, e.g. \\emph or \\texttt."
    ignorecase: true
    level: warning
    nonword: true
    linter:
      - latex
    tokens:
      - (?<=\s')(\w.*?\b)(?=`|'|"|”)
      # Check for correct start but incorrect end.
      - (?<=\s`)(\w.*?\b)(?=`|"|”|'')

Enforce typographically correct quotation marks (double):

.. code-block:: YAML

    extends: existence
    message: "Unexpected quotation mark, consider using ``$1'' or using an emphasis macro, e.g. \\emph or \\texttt."
    ignorecase: true
    level: warning
    nonword: true
    linter:
      - latex
    tokens:
      - (?<="|”|'')(\w.*?\b)(?="|'|”|`)
      # Check for correct start but incorrect end.
      - (?<=``)(\w.*?\b)(?="|”|`|'\s)

Check for camel case identifiers inside the ``\texttt`` control sequence and
suggest adding two parentheses:

.. code-block:: YAML

    extends: existence
    message: "Add two parentheses '()' to the end of the function '$1'."
    ignorecase: false
    nonword: true
    level: error
    linter:
      - latex
    latex:
      - name: texttt
        type: control sequence
    tokens:
      - '(?<!:|\/|\\)([a-z]*)([A-Z]+[a-z0-9][A-za-z0-9]*){2,}+(?!\/)(?!\()'

Check for identifiers that should be typeset using the TeX typewriter font, i.e.
enclosed in ``\texttt``:

.. code-block:: YAML

    extends: existence
    message: "Use \\texttt to typeset '$1'."
    ignorecase: false
    nonword: true
    level: error
    linter:
      - latex
    latex:
      - name: document
        type: environment
        logic: and
      - name: texttt
        type: control sequence
        logic: not
      - name: href
        type: control sequence
        logic: not
      - name: cite
        type: control sequence
        logic: not
      - name: lstlisting
        type: environment
        logic: not
      - name: includegraphics
        type: control sequence
        logic: not
      - name: input
        type: control sequence
        logic: not
    tokens:
      # Pascal & camel case identifiers, except when preceded by ':', '/' or '\' (paths).
      - (?<!:|\/|\\)([a-z]*)([A-Z]+[a-z0-9][A-za-z0-9]*){2,}
      # Snake case identifiers, except when preceded by ':', '/' or '\' (paths).
      - (?<!:|\/|\\)\b[a-z][a-z0-9]+(_[a-z0-9]+){1,}\b
      # Filenames
      - \b\w{3,}\.[a-z]+\b
    exceptions:
      - CentOS
      - OpenSuse
