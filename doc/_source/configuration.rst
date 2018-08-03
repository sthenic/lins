.. _`lins_cfg`:

*************
Configuration
*************

Configuring the tool through a *configuration file*  allows you to specify paths
to :ref:`directories <cfg_rule_dirs>` containing :ref:`rule files <lins_rules>`
and to define :ref:`styles <cfg_styles>` from these files.

.. _`cfg_file`:

Configuration File
==================

The configuration file is expected to be named ``.lins.cfg`` or ``lins.cfg`` and
uses a syntax similar to Windows' ``.ini`` files. The tool determines which
configuration file to use through a search that follows these parameters:

* The path to the current working directory is traversed in ascending order
  until a configuration file is found or the root directory is reached.
  Additionally, the search algorithm descends into any directory named ``.lins``
  on its way to the root.

* If the directory traversal yields no results, the tool looks in current user's
  home directory (e.g. ``/home/<user>`` on Unix systems and ``C:\Users\<user>``
  on Windows systems).

Upon finding a configuration file, the search is aborted and its contents are
parsed.

You are also able to specify a configuration file by setting the ``LINS_CFG``
environment variable to the full path of the configuration file. This method
takes precedence over any file found through the search outlined above.

.. note::

    The absolute path of the selected configuration file is reported at runtime.

.. note::

    You can disable the use of a configuration file by specifying the option
    ``--no-cfg``.

Below is an example of a configuration file. The following sections break down
and explain its contents.

.. literalinclude:: lins.cfg
    :language: cfg

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

.. Something about that sharing rule files between styles is made simple?

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

Each style is defined in its own ``Style`` section. Immediately following the
section title, the style's ``name`` is expected. Additionally, ``default``
keyword may be used to select this as the *default style*. Unless another style
is specified using the ``--style`` option, the default style will automatically
be selected when invoking the tool.

.. literalinclude:: lins.cfg
    :language: cfg
    :lines: 5-7

To assign rules to a style the ``rule`` keyword is used together with a target
label (defined in the ``RuleDirs`` section). This will include all rules defined
in the label's target directory (unless the ``Except`` or ``Only`` sections are
used).

.. literalinclude:: lins.cfg
    :language: cfg
    :lines: 14

Except and Only
###############

The ``Except`` and ``Only`` sections applies to the latest ``rule`` keyword and
are mutually exclusive, i.e. a rule can make use of either the ``Except``
section or the ``Only`` section, but not both.

The purpose of each section is straight-forward:

* The ``Except`` section includes all rule files *except* the ones listed in
  the section.

.. literalinclude:: lins.cfg
    :language: cfg
    :lines: 9-13

* The ``Only`` section *only* includes the rule files listed in the section.

.. literalinclude:: lins.cfg
    :language: cfg
    :lines: 19-21

In both cases, the lists consist of filenames (case sensitive and without the
extension) with one entry per line.

.. _`cfg_env`:

Environment Variables
=====================

Environment variables offer yet another way of configuring the tool in a
persistent manner.

* ``LINS_CFG``---full path to a configuration file. This takes precedence over
  any file located through the search described in :ref:`cfg_file`, provided
  the specified file exists.

* ``LINS_DEFAULT_STYLE``---name of the default :ref:`style <cfg_styles>`. This
  name is case sensitive and must match a style defined in the active
  configuration file. If these criteria are met, this takes precedence over any
  default style defined in the configuration file.
