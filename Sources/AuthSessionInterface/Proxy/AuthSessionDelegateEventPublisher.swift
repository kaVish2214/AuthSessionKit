// Copyright (c) 2026 kaVi Gevariya (@kaVish2214)
// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation


/// A type that delivers ``AuthSessionDelegateEvent`` values to a single, private listener.
///
/// `AuthSessionDelegateEventPublisher` is the outbound counterpart of
/// ``AuthSessionEventPublisher``. Where ``AuthSessionEventPublisher`` carries
/// raw lifecycle events from a session provider **into** the handle,
/// this protocol carries delegate-shaped events **out** of the handle to a
/// listener that wants the same signals without conforming to
/// ``AuthSessionDelegate`` publicly.
///
/// Implementations are typically wrapped by an ``AuthSessionDelegateEventProxy``
/// so the routing reaction lives inside an init-time closure.
public protocol AuthSessionDelegateEventPublisher: Sendable {

    /// Delivers a delegate-shaped event, optionally associated with the originating handle.
    /// - Parameters:
    ///   - event: The event mirroring an ``AuthSessionDelegate`` callback.
    ///   - sessionHandle: The handle that produced the event, or `nil` for synthetic emissions.
    func publish(_ event: AuthSessionDelegateEvent, for sessionHandle: (any AuthSessionHandleProtocol)?)
}
