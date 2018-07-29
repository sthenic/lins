.. _`lins_usage`:

*****
Usage
*****

Lins is a command-line tool---meaning that most of the time, the user will
interface with the tool through a terminal session. Linting a text file involves
invoking Lins with the path to the target file as an input argument.

.. code-block:: bash

    $ lins my_file.txt

The input file has to be encoded in UTF-8 (of which ASCII is a subset) and not
contain anything other than the target text. Files from other word processing
applications often contain, apart from the text itself, additional data specific
to that tool. These types of files are not supported.

.. Provided there are some :ref:`rules <lins_rules>` and a default :ref:`style
.. <cfg_styles>` defined, the output may look similar to this:

.. .. image:: /_static/usage.png

Command Line Interface
======================

.. literalinclude:: /../src/help_cli.txt
    :language: text
