// Copyright (c) 2026 kaVi Gevariya (@kaVish2214)
// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation


/// A type that routes ``AuthSessionDelegateEvent`` values to an init-time closure.
///
/// `AuthSessionDelegateEventProxy` is the recommended seam for private listeners —
/// types that need to react to session events without exposing public
/// ``AuthSessionDelegate`` methods on their own API.
///
/// The proxy is initialized with a `@MainActor @Sendable` closure that owns the
/// entire routing reaction. The proxy itself is a transparent forwarder; it
/// never inspects or modifies the event.
///
/// Conformers typically also adopt ``AuthSessionDelegateEventPublisher`` so
/// they can be handed to a producer that calls `publish(_:for:)`.
///
/// ## Usage
/// ```swift
/// let proxy: any AuthSessionDelegateEventProxy = ConcreteProxy { [weak self] event in
///     switch event {
///     case .sessionStatusChanged(_, let newValue) where newValue.isSignedOut:
///         self?.reset()
///     case .userUpdate:
///         self?.reload()
///     default:
///         break
///     }
/// }
/// ```
public protocol AuthSessionDelegateEventProxy: Sendable {

    /// Designated initializer.
    ///
    /// - Parameter eventListening: The closure invoked once per upstream
    ///   delegate callback, on the main actor. Owns the entire routing
    ///   reaction; the proxy never inspects or modifies the event.
    init(eventListening: @escaping @MainActor @Sendable (AuthSessionDelegateEvent) -> Void)
}
