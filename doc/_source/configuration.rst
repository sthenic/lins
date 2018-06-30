.. _`lins_cfg`:

*************
Configuration
*************

.. _`cfg_file`:

Configuration File
==================

.. * File naming
.. * Search behavior
.. * Format?

.. _`cfg_rule_dirs`:

Rule Directories
================

.. * Specifiying rule dirs
.. * No recursive search

.. _`cfg_styles`:

Styles
======

:ref:`Rule files <lins_rules>` may be grouped together to form a *style*. Styles
are important for a few reasons:

.. Something about that sharing rule files between styles are made simple?

* *Flexibility*---by adding an abstraction layer between the rule files and the
  user, you gain flexibility.

* *File structure*---since you explicitly select which rule files should be
  included in a particular style, the tool imposes no requirements on how the
  rule files are organized.

* *Ease of use*---when linting, the user only specifies a style and is not
  affected by the style's maintainer removing and adding rule files.


Perhaps Marketing uses a different style than R&D when writing documents. For
example, two styles may share the same core rule set but one may enforce the
*passive voice* while the other enforces the *active voice*.

.. _`cfg_define_style`:

Defining a Style
----------------

.. * Naming the style
.. * Default style
.. * Adding rule dirs (by name)

Except and Only
###############



