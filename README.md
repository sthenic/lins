[![NIM](https://img.shields.io/badge/Nim-0.19.2-orange.svg?style=flat-square)](https://nim-lang.org)
[![LICENSE](https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square)](https://opensource.org/licenses/MIT)
[![pipeline status](https://gitlab.com/sthenic/lins/badges/latest/pipeline.svg)](https://gitlab.com/sthenic/lins/commits/latest)

# README
Lins is a lightweight, extensible linter for prose. The tool is written in [Nim](https://nim-lang.org) and inspired by [Vale](https://github.com/errata-ai/vale).

## Documentation
The project's documentation is available [here](https://sthenic.gitlab.io/lins).

## Version numbers
Releases follow [semantic versioning](https://semver.org/) to determine how the version number is incremented. If the specification is ever broken by a release, this will be documented in the changelog.

## Reporting a bug
If you discover a bug or what you believe is unintended behavior, please submit an issue on the [issue board](https://gitlab.com/sthenic/lins_nim/issues). A minimal working example and a short description of the context is appreciated and goes a long way towards being able to fix the problem quickly.

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
