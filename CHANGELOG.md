# CHANGELOG

All notable changes to this project will be documented in this file.

## v0.3.1 - 2018-08-09

* Fixed ANSI escape sequences not being suppressed when piping the output to another application or a file.
* Fixed an issue where the violation counters were not being reset going from one input file to the next.

## v0.3.0 - 2018-08-08

* Added the `--no-color` option to suppress colored output.

## v0.2.2 - 2018-08-07

* Fixed an issue with the substitution rule's violation guard introduced in v0.2.0. Strings are now converted to lower-case and compared if the `ignore_case` property is set to `true`.

## v0.2.1 - 2018-08-06

* Updated CI configuration. Now builds `.deb` package for Ubuntu 16.04.

## v0.2.0 - 2018-08-04

* Added support for input file selection through glob patterns.
* Updated the configuration file search algorithm.
* Ensured that log level suppression yields the correct exit code.
* Added environment variables `LINS_CFG` and `LINS_DEFAULT_STYLE`.
* Added the `--list` option to display available styles and the current rule set.
* The substitution rule no longer reports a violation if the key regex happens to also match text equal to the substitution value.

## v0.1.1 - 2018-08-02

* Fixed an issue with the .deb package build script.

## v0.1.0 - 2018-07-29

* This is the first release of the project.
