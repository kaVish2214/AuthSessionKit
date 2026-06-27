// Copyright (c) 2026 kaVi Gevariya (@kaVish2214)
// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation


/// A type that delivers authentication session lifecycle events.
///
/// Session providers call ``publish(_:for:)`` to push ``AuthSessionEvent``
/// notifications through the proxy chain. A convenience overload omits the
/// provider parameter for internal callers.
public protocol AuthSessionEventPublisher: AnyObject, Sendable {

    /// Delivers a session lifecycle event, optionally associated with a specific provider.
    /// - Parameters:
    ///   - event: The event describing the current session state change.
    ///   - sessionProvider: The provider that originated the event, or `nil` for internal events.
    func publish(_ event: AuthSessionEvent, for sessionProvider: (any AuthSessionProviderProtocol)?)
}

extension AuthSessionEventPublisher {

    /// Convenience for delivering an event without a provider reference.
    public func publish(_ event: AuthSessionEvent) {
        self.publish(event, for: nil)
    }
}
