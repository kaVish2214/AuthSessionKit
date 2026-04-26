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

    /// Called when a session fetch completes successfully.
    /// - Parameters:
    ///   - session: The current session, or `nil` if no session was returned.
    ///   - isInitialFetch: `true` if this is the first fetch at launch; `false` for subsequent refreshes.
    func session(_ session: (any AuthSessionInterface)?, sessionFetchDidComplete isInitialFetch: Bool)

    /// Called when the session status transitions to a new value.
    /// - Parameters:
    ///   - session: The current session, or `nil` if the user is signed out.
    ///   - sessionStatus: The new session status.
    ///   - oldStatus: The previous session status before the transition.
    func session(_ session: (any AuthSessionInterface)?, didUpdate sessionStatus: any AuthSessionStatusInterface, where oldStatus: any AuthSessionStatusInterface)

    /// Called when the user successfully signs in.
    /// - Parameters:
    ///   - session: The newly established session.
    ///   - user: The authenticated user, or `nil` if user information is unavailable.
    func session(_ session: (any AuthSessionInterface)?, didLogin user: (any AuthSessionUserInterface)?)

    /// Called when the user signs out.
    /// - Parameters:
    ///   - session: The session that was active before sign-out, or `nil`.
    ///   - error: The error that triggered the sign-out, or `nil` for a voluntary sign-out.
    func session(_ session: (any AuthSessionInterface)?, didLogoutWith error: Error?)

    /// Called when the authenticated user's information changes.
    /// - Parameters:
    ///   - session: The current session.
    ///   - user: The updated user, or `nil` if user information is unavailable.
    func session(_ session: (any AuthSessionInterface)?, didUpdate user: (any AuthSessionUserInterface)?)

    /// Called when a session operation fails with an error.
    /// - Parameters:
    ///   - session: The current session, or `nil` if no session is active.
    ///   - error: The ``AuthSessionError`` describing the failure.
    func session(_ session: (any AuthSessionInterface)?, didFailWith error: AuthSessionError)
}

// MARK: - Optional Defaults

extension AuthSessionDelegate {

    public func session(_ session: (any AuthSessionInterface)?, sessionFetchDidComplete isInitialFetch: Bool) { }

    public func session(_ session: (any AuthSessionInterface)?, didFailWith error: AuthSessionError) { }

    public func session(_ session: (any AuthSessionInterface)?, didUpdate user: (any AuthSessionUserInterface)?) { }
}
