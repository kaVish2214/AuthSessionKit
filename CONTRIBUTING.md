# Contributing to AuthSessionKit

Thanks for your interest in improving `AuthSessionKit`! This document explains
how to propose changes, the standards we hold code to, and what to expect during
review.

By participating in this project you agree to abide by our
[Code of Conduct](CODE_OF_CONDUCT.md).

## Licensing of contributions

`AuthSessionKit` is licensed under the [Mozilla Public License 2.0](LICENSE).
By submitting a contribution you agree that your contribution is licensed under
the MPL-2.0, and that any file you create or modify carries the standard MPL
header (see [Source headers](#source-headers)).

The MPL is **file-level copyleft**: if you modify an MPL-covered file, your
modifications to that file must remain open-source under the MPL. New files you
add alongside the covered code may use a different license, but contributions
*into this repository* must be MPL-2.0.

## Getting started

1. **Fork** the repository and create a topic branch off `main`:
   ```sh
   git checkout -b feature/short-description
   ```
2. **Build** the package:
   ```sh
   swift build
   ```
3. **Run the tests** (see [Testing](#testing)):
   ```sh
   swift test
   ```

## Project layout

This package ships two products — depend on the smallest surface you need:

- **`AuthSessionInterface`** — protocols, enums, errors, events, delegates. No
  implementation logic. Feature modules and test doubles depend on this.
- **`AuthSession`** — the concrete `AuthSessionHandle` and supporting types.

See the [README](README.md) for the full module map and architecture.

## Coding standards

- **Swift 6 / strict concurrency.** The package builds under
  `swiftLanguageModes: [.v6]`. New code must compile without concurrency
  warnings. Don't reach for `@unchecked Sendable` unless you can justify it —
  prefer the lock-protected `State` pattern (`ConcurrencySafeContainer`) already
  used by `AuthSessionHandle`.
- **No warnings.** The build and test targets must be warning-free.
- **Document public API** with `///` doc comments. Match the density and style
  of the surrounding code. Keep docs accurate — stale docs are treated as bugs.
- **Naming:** PascalCase for types, camelCase for properties/methods.
- **Formatting:** 4-space indentation, clear method separation.
- **Avoid Combine** — prefer `async`/`await` and the existing delegate / event
  proxy patterns.

### Source headers

Every Swift source file must begin with the standard header:

```swift
// Copyright (c) 2026 kaVi Gevariya (@kaVish2214)
// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
```

## Testing

- Tests use Apple's [Swift Testing](https://developer.apple.com/documentation/testing/)
  framework (`@Test`, `@Suite`, `#expect`).
- New behavior needs test coverage. Bug fixes should include a regression test.
- Concurrency-sensitive changes belong in (or alongside) the `Thread Safety`
  suite, which is marked `.serialized` because each test runs its own
  concurrent stress load.
- The full suite must pass with **zero warnings and zero failures** before a PR
  is merged.

## Submitting a pull request

1. Keep PRs focused — one logical change per PR.
2. Update documentation (`///` comments and `README.md`) for any public API
   change. Don't leave stale docs behind.
3. Add a `CHANGELOG.md` entry under the `## [Unreleased]` heading describing
   your change (Added / Changed / Fixed / Removed).
4. Ensure `swift build` and `swift test` are clean.
5. Write a clear PR description: what changed, why, and how it was verified.

## Reporting bugs and requesting features

- Open a GitHub issue with a clear title and a minimal reproduction.
- For security vulnerabilities, **do not** open a public issue — follow the
  [Security Policy](SECURITY.md) instead.

Thank you for contributing!
