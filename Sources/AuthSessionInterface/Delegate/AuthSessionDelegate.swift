// Copyright (c) 2026 kaVi Gevariya (@kaVish2214)
// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import MultiCastDelegate

/// A delegate protocol for observing authentication session lifecycle changes.
///
/// Conforms to ``MultiCastDelegate``, enabling multiple observers to subscribe
/// to session events simultaneously through the handle's ``DelegateMultiCasting`` support.
///
/// Methods with default (no-op) implementations are optional — override only the
/// callbacks your observer needs.
public protocol AuthSessionDelegate: MultiCastDelegate {

    /// Called when a session fetch completes (initial launch or subsequent refresh).
    /// - Parameters:
    ///   - sessionHandle: The handle that owns the session.
    ///   - session: The fetched session, or `nil` if no session exists.
    ///   - flag: `true` for the first fetch at launch; `false` for refreshes.
    func authentication(_ sessionHandle: (any AuthSessionHandleProtocol)?, didCompleteFetchWith session: (any AuthSessionProtocol)?, isInitialFetch flag: Bool)

    /// Called whenever the session status transitions to a new value.
    /// - Parameters:
    ///   - sessionHandle: The handle that owns the session.
    ///   - sessionStatus: The new status.
    ///   - oldStatus: The previous status.
    ///   - session: The current session, or `nil`.
    func authentication(_ sessionHandle: (any AuthSessionHandleProtocol)?, didUpdateStatus sessionStatus: any AuthSessionStatusProtocol, from oldStatus: any AuthSessionStatusProtocol, for session: (any AuthSessionProtocol)?)

    /// Called when the user successfully signs in.
    /// - Parameters:
    ///   - sessionHandle: The handle that owns the session.
    ///   - user: The authenticated user, or `nil` if unavailable.
    ///   - session: The session associated with the sign-in.
    func authentication(_ sessionHandle: (any AuthSessionHandleProtocol)?, didLoginWith user: (any AuthSessionUserProtocol)?, for session: (any AuthSessionProtocol)?)

    /// Called when the user signs out.
    /// - Parameters:
    ///   - sessionHandle: The handle that owns the session.
    ///   - error: The error that triggered the sign-out, or `nil` for voluntary sign-out.
    func authentication(_ sessionHandle: (any AuthSessionHandleProtocol)?, didLogoutWith error: Error?)

    /// Called when the session's user data changes without a status transition.
    /// - Parameters:
    ///   - sessionHandle: The handle that owns the session.
    ///   - user: The updated user, or `nil`.
    ///   - session: The current session.
    func authentication(_ sessionHandle: (any AuthSessionHandleProtocol)?, didUpdate user: (any AuthSessionUserProtocol)?, for session: (any AuthSessionProtocol)?)

    /// Called when an error occurs during session operations.
    /// - Parameters:
    ///   - sessionHandle: The handle that owns the session.
    ///   - error: The session error.
    ///   - session: The current session, or `nil`.
    func authentication(_ sessionHandle: (any AuthSessionHandleProtocol)?, didFailWith error: AuthSessionError, for session: (any AuthSessionProtocol)?)
}

// MARK: - Optional Defaults

extension AuthSessionDelegate {

    public func authentication(_ sessionHandle: (any AuthSessionHandleProtocol)?, didCompleteFetchWith session: (any AuthSessionProtocol)?, isInitialFetch flag: Bool) { }

    public func authentication(_ sessionHandle: (any AuthSessionHandleProtocol)?, didFailWith error: AuthSessionError, for session: (any AuthSessionProtocol)?) { }

    public func authentication(_ sessionHandle: (any AuthSessionHandleProtocol)?, didUpdate user: (any AuthSessionUserProtocol)?, for session: (any AuthSessionProtocol)?) { }
}
