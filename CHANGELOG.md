# Changelog

All notable changes to `AuthSessionKit` are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.1] - 2026-07-07

### Added
- **Mac Catalyst support.** The package now declares `.macCatalyst(.v14)`
  alongside iOS 14+ and macOS 10.15+.

### Changed
- **`UtilityKit` updated to 0.1.1.**

## [0.1.0] - 2026-06-27

Initial public release. AuthSessionKit provides a thread-safe, protocol-first
foundation for managing authentication sessions on Apple platforms.

### Added
- **Two products.** `AuthSessionInterface` (the public protocol/enum/error
  contract, with no implementation) and `AuthSession` (the concrete session
  handle). Feature modules can depend on the interface alone for fast builds and
  easy mocking.
- **`AuthSessionHandle`.** Coordinates the full session lifecycle: fetching,
  local expiry validation, biometric gating (Face ID / Touch ID), sign-in,
  sign-out, and status transitions. Automatically re-validates when the app
  returns to the foreground.
- **Pluggable providers.** Bring your own backend by conforming to
  `AuthSessionProviderProtocol` — the package ships no networking and makes no
  assumptions about your auth service.
- **Observation, two ways.** Subscribe many observers through the multicast
  `AuthSessionDelegate`, or react privately via a main-actor closure
  (`AuthSessionDelegateEventProxy`) without exposing delegate methods in your
  own API.
- **Thread-safe by construction.** The session handle is safe to drive from any
  thread, actor, or queue, backed by an OS-adaptive lock.
- **Cross-platform.** iOS 14+ and macOS 10.15+ (UIKit and AppKit foreground
  handling).
- Licensed under the Mozilla Public License 2.0.

[Unreleased]: https://github.com/kaVish2214/AuthSessionKit/compare/0.1.1...HEAD
[0.1.1]: https://github.com/kaVish2214/AuthSessionKit/compare/0.1.0...0.1.1
[0.1.0]: https://github.com/kaVish2214/AuthSessionKit/releases/tag/0.1.0
