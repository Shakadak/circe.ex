# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

## [0.2.1] 2022-12-03

### Fixed

* Can now match on 2-tuples.

## [0.2.0] 2022-05-14

### Added

* Spliced matching now uses `...x` instead of `[spliced: x]`.

### Deprecated

* Spliced matching using `[spliced: x]` now prints a warning.

## [0.1.0] - 2021-05-14

### Added

* Base implementation  
  `Circe.sigil_m/2` : seems to work for all ASTs. (in hindsight, it didn't)

---

Changelog format inspired by [keep-a-changelog]

[keep-a-changelog]: https://github.com/olivierlacan/keep-a-changelog
[unreleased]: https://github.com/shakadak/circe.ex/compare/v0.2.0...HEAD
[0.2.1]: https://github.com/shakadak/circe.ex/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/shakadak/circe.ex/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/shakadak/circe.ex/compare/v0.0.0...v0.1.0
