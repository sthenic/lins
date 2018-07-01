.. _`lins_cfg`:

*************
Configuration
*************

Documentation coming soon.

.. _`cfg_file`:

Configuration File
==================

Documentation coming soon.

.. literalinclude:: lins.cfg
    :language: cfg

.. * File naming
.. * Search behavior
.. * Format?

.. _`cfg_rule_dirs`:

Rule Directories
================

.. literalinclude:: lins.cfg
    :language: cfg
    :lines: 1-3

Rule directories are specified in the ``RuleDirs`` section. The directories are
not traversed recursively so only rule files residing on the top level are
added. Entries are separated by line breaks and may explicitly be assigned a
*label* by using the ``=`` character. Entries without an explicit label will
use the name of their lowest-level directory.

.. note::

    Relative paths are computed w.r.t. the path of the configuration file.


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

Documentation coming soon.

.. literalinclude:: lins.cfg
    :language: cfg
    :lines: 5-14

Except and Only
###############

Documentation coming soon.

.. literalinclude:: lins.cfg
    :language: cfg
    :lines: 9-13,19-21
