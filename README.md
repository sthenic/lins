[![NIM](https://img.shields.io/badge/Nim-1.2.4-orange.svg?style=flat-square)](https://nim-lang.org)
[![LICENSE](https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square)](https://opensource.org/licenses/MIT)
![Travis (.org) branch](https://img.shields.io/travis/sthenic/lins/master.svg?style=flat-square)

# ![lins](/doc/logo/logo.png?raw=true)
Lins is a lightweight, extensible linter for prose—specifically developed with LaTeX in mind. The tool is written in [Nim](https://nim-lang.org) and inspired by [Vale](https://github.com/errata-ai/vale).

## Documentation
The project's documentation is available [here](https://sthenic.github.io/lins).

## Building

If none of the [release packages](https://github.com/sthenic/lins/releases)
targets your platform, you can still build and use this tool provided that
you have a C compiler that targets your platform.

1. Download and install the [Nim](https://nim-lang.org/install.html) compiler
   and its tools.

2. Clone this repository and run

       nimble install

3. Since Lins relies on [PCRE](http://pcre.sourceforge.net) for its regular
   expression support via dynamic linking, you will also have to build or
   install PCRE as a library.

## Version numbers
Releases follow [semantic versioning](https://semver.org/) to determine how the version number is incremented. If the specification is ever broken by a release, this will be documented in the changelog.

## Reporting a bug
If you discover a bug or what you believe is unintended behavior, please submit an issue on the [issue board](https://github.com/sthenic/lins/issues). A minimal working example and a short description of the context is appreciated and goes a long way towards being able to fix the problem quickly.

## License
Lins is free software released under the [MIT license](https://opensource.org/licenses/MIT).

## Third-party dependencies

* [Nim's standard library](https://github.com/nim-lang/Nim)
* [NimYAML](https://github.com/flyx/NimYAML)
* Regular expression support is provided by the
  [PCRE](http://pcre.sourceforge.net) library package, which is open source
  software, written by Philip Hazel, and copyright by the University of
  Cambridge, England.

## Author
Lins is maintained by [Marcus Eriksson](mailto:marcus.jr.eriksson@gmail.com).
