//
//  AuthSessionDelegate.swift
//  AuthSessionKit
//
//  Created by kavi gevariya on 26/04/26.
//

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
    func authentication(_ sessionHandle: (any AuthSessionHandleInterface)?, didCompleteFetchWith session: (any AuthSessionInterface)?, isInitialFetch flag: Bool)

    /// Called whenever the session status transitions to a new value.
    /// - Parameters:
    ///   - sessionHandle: The handle that owns the session.
    ///   - sessionStatus: The new status.
    ///   - oldStatus: The previous status.
    ///   - session: The current session, or `nil`.
    func authentication(_ sessionHandle: (any AuthSessionHandleInterface)?, didUpdateStatus sessionStatus: any AuthSessionStatusInterface, from oldStatus: any AuthSessionStatusInterface, for session: (any AuthSessionInterface)?)

    /// Called when the user successfully signs in.
    /// - Parameters:
    ///   - sessionHandle: The handle that owns the session.
    ///   - user: The authenticated user, or `nil` if unavailable.
    ///   - session: The session associated with the sign-in.
    func authentication(_ sessionHandle: (any AuthSessionHandleInterface)?, didLoginWith user: (any AuthSessionUserInterface)?, for session: (any AuthSessionInterface)?)

    /// Called when the user signs out.
    /// - Parameters:
    ///   - sessionHandle: The handle that owns the session.
    ///   - error: The error that triggered the sign-out, or `nil` for voluntary sign-out.
    func authentication(_ sessionHandle: (any AuthSessionHandleInterface)?, didLogoutWith error: Error?)

    /// Called when the session's user data changes without a status transition.
    /// - Parameters:
    ///   - sessionHandle: The handle that owns the session.
    ///   - user: The updated user, or `nil`.
    ///   - session: The current session.
    func authentication(_ sessionHandle: (any AuthSessionHandleInterface)?, didUpdate user: (any AuthSessionUserInterface)?, for session: (any AuthSessionInterface)?)

    /// Called when an error occurs during session operations.
    /// - Parameters:
    ///   - sessionHandle: The handle that owns the session.
    ///   - error: The session error.
    ///   - session: The current session, or `nil`.
    func authentication(_ sessionHandle: (any AuthSessionHandleInterface)?, didFailWith error: AuthSessionError, for session: (any AuthSessionInterface)?)
}

// MARK: - Optional Defaults

extension AuthSessionDelegate {

    public func authentication(_ sessionHandle: (any AuthSessionHandleInterface)?, didCompleteFetchWith session: (any AuthSessionInterface)?, isInitialFetch flag: Bool) { }

    public func authentication(_ sessionHandle: (any AuthSessionHandleInterface)?, didFailWith error: AuthSessionError, for session: (any AuthSessionInterface)?) { }

    public func authentication(_ sessionHandle: (any AuthSessionHandleInterface)?, didUpdate user: (any AuthSessionUserInterface)?, for session: (any AuthSessionInterface)?) { }
}
