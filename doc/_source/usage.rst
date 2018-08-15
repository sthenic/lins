.. _`lins_usage`:

*****
Usage
*****

Lins is a command-line tool---meaning that most of the time, the user will
interface with the tool through a terminal session. Linting a text file involves
invoking Lins with the path to one or several target files as input arguments.

.. code-block:: bash

    $ lins my_file.txt

The input file has to be encoded in UTF-8 (of which ASCII is a subset) and not
contain anything other than the target text. Files from other word processing
applications often contain, apart from the text itself, additional data specific
to that tool. These types of files are not supported.

Pattern Matching
================

Selecting target files based on a pattern is supported. However, the extent of
this support is OS-dependent. The ``*.ext`` notation is always supported. POSIX
systems use the ``glob`` call which enables wildcarding directories. For example,

.. code-block:: bash

    $ lins **/*.txt

descends one level into every directory in the current working directory and
grabs every file with the ``.txt`` extension.

.. Provided there are some :ref:`rules <lins_rules>` and a default :ref:`style
.. <cfg_styles>` defined, the output may look similar to this:

.. .. image:: /_static/usage.png

Command Line Interface
======================

.. literalinclude:: /../src/help_cli.txt
    :language: text
