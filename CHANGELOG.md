# CHANGELOG

All notable changes to this project will be documented in this file.

## v0.7.0 - 2021-05-20

* The plain text parser now ignores empty segments, just like the LaTeX parser.
* (LaTeX) Fix an issue where the leading context for capture groups following a
  control word or environment was not set correctly for any group but the first
  one.
* (LaTeX) Fix a potential access violation that would cause the application to
  crash.
* (LaTeX) The control word `\textbackslash` now inserts a backslash character
  into the text segment instead of being removed completely.
* (LaTeX) **BREAKING** The name of the context labels `before`/`after` have been
  changed to `leading`/`trailing`. LaTeX scope entries in a rule file now expect
  to a field called `leading` instead of `before`.
* The existence rule now features the field `invert` (`false` by default) that
  causes the matching logic to be inverted if set to `true`, i.e. if the text
  segment does *not* contain any of the listed `tokens`, a violation is
  generated. One important detail is that when `invert` is `true`, the
  `message` is *not* provided any text to match the replacement field `$1`.
* Refactored code for better maintainablilty.

## v0.6.1 - 2019-05-11

* Repository is now hosted on Github. No functional changes.

## v0.6.0 - 2019-05-08

* Major refactoring completed to add support for a LaTeX linter. No breaking
  changes are expected. There's still a plain text linter which is selected by
  default. The LaTeX linter is chosen automatically for files with the `.tex` or
  `.sty` extensions. Please refer to the project documentation for details on
  the new functionality.

## v0.5.1 - 2018-08-28

* Fix the generation of the static web documentation.

## v0.5.0 - 2018-08-28

* Update the plain text lexer.

## v0.4.0 - 2018-08-19

* Searching for a configuration file directly in the user's home has been
  replaced by instead looking in the user's configuration directory, e.g.
  ``~/.config``. This new method respects ``XDG_CONFIG_HOME`` on Unix systems.
* Expand '~' when parsing ``--rule-dir`` values.
* Improve documentation and CLI help text.
* A lot of internal refactoring and cleanup (not affecting functionality).

## v0.3.1 - 2018-08-09

* Fix ANSI escape sequences not being suppressed when piping the output to
  another application or a file.
* Fix an issue where the violation counters were not being reset going from one
  input file to the next.

## v0.3.0 - 2018-08-08

* Add the `--no-color` option to suppress colored output.

## v0.2.2 - 2018-08-07

* Fix an issue with the substitution rule's violation guard introduced in
  v0.2.0. Strings are now converted to lower-case and compared if the
  `ignore_case` property is set to `true`.

## v0.2.1 - 2018-08-06

* Update CI configuration. Now builds `.deb` package for Ubuntu 16.04.

## v0.2.0 - 2018-08-04

* Add support for input file selection through glob patterns.
* Update the configuration file search algorithm.
* Ensure that log level suppression yields the correct exit code.
* Add environment variables `LINS_CFG` and `LINS_DEFAULT_STYLE`.
* Add the `--list` option to display available styles and the current rule set.
* The substitution rule no longer reports a violation if the key regex happens
  to also match text equal to the substitution value.

## v0.1.1 - 2018-08-02

* Fix an issue with the .deb package build script.

## v0.1.0 - 2018-07-29

* This is the first release of the project.
