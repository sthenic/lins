************
Introduction
************

Lins is a lightweight, extensible linter for prose. The tool is written in
`Nim`_ and inspired by `Vale <https://github.com/errata-ai/vale>`_.

.. _Nim: https://nim-lang.org

.. note::

    The source code may be found in the project's `Gitlab repository`_.

.. _Gitlab repository: http://gitlab.com/sthenic/lins

This documentation is generated with `Sphinx`_ using the `Alabaster`_ theme.

.. _Sphinx: http://www.sphinx-doc.org/
.. _Alabaster: https://github.com/bitprophet/alabaster/

Features
========

* Full Unicode support
* Able to handle in-sentence line breaks
* Rules are defined using `YAML`_
* Define styles from a collection of rules

.. _YAML: http://yaml.org/

Contents
========

The documentation is organized into the following sections:

.. toctree::
  :maxdepth: 2

  _source/installation
  _source/usage
  _source/configuration
  _source/rules
  _source/examples


Reporting Issues
================

If you discover a bug or what you believe is unintended behavior, please submit
an issue on the `issue board`_. A minimal working example and a short
description of the context is appreciated and goes a long way towards being able
to fix the problem quickly.

Roadmap
=======

Have a look at the project's upcoming `milestones`_ to see where we're headed.


Additionally, if you have a feature you would like to see added to the tool or
perhaps an enhancement of an existing feature, please register an issue on the
`issue board`_.

.. _milestones: https://gitlab.com/sthenic/lins/milestones
.. _issue board: https://gitlab.com/sthenic/lins/issues

License
=======

Lins is released under the `MIT license`_.

.. _MIT License: https://gitlab.com/sthenic/lins/blob/master/LICENSE

Third-party Dependencies
========================

* `Nim's standard library`_ (`LICENSE <https://github.com/nim-lang/Nim/blob/master/copying.txt>`_)
* `NimYAML`_ (`LICENSE <https://github.com/flyx/NimYAML/blob/master/copying.txt>`_)
* `PCRE`_ (`LICENSE <http://pcre.sourceforge.net/license.txt>`_)


.. _`Nim's standard library`: https://github.com/nim-lang/Nim
.. _NimYAML: https://github.com/flyx/NimYAML
.. _PCRE: http://pcre.sourceforge.net
