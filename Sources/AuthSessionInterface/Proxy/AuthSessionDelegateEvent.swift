//
//  AuthSessionDelegateEvent.swift
//  RouteKit
//
//  Created by kavi gevariya on 18/05/26.
//

import Foundation

/// A flat-enum mirror of the ``AuthSessionDelegate`` callbacks.
///
/// `AuthSessionDelegateEvent` is the payload pushed through an
/// ``AuthSessionDelegateEventPublisher``. Each case maps one-for-one to a
/// method on ``AuthSessionDelegate``, so a single closure can react to
/// every outbound session signal with a `switch` instead of conforming to
/// the full delegate protocol.
///
/// Use this channel when a type needs to react to session events but should
/// **not** expose public delegate methods as part of its API.
public enum AuthSessionDelegateEvent: Sendable {

    /// The session provider completed a fetch.
    /// - Parameter isInitial: `true` for the launch-time fetch; `false` for refreshes.
    ///
    /// Mirrors ``AuthSessionDelegate/authentication(_:didCompleteFetchWith:isInitialFetch:)``.
    case sessionFetch(isInitial: Bool)

    /// The user signed in.
    ///
    /// Mirrors ``AuthSessionDelegate/authentication(_:didLoginWith:for:)``.
    case login

    /// The user signed out.
    /// - Parameter error: The error that triggered the sign-out, or `nil` for a voluntary sign-out.
    ///
    /// Mirrors ``AuthSessionDelegate/authentication(_:didLogoutWith:)``.
    case logout(error: Error?)

    /// The session status transitioned to a new value.
    /// - Parameters:
    ///   - oldValue: The previous status.
    ///   - newValue: The new status.
    ///
    /// Mirrors ``AuthSessionDelegate/authentication(_:didUpdateStatus:from:for:)``.
    case sessionStatusChanged(oldValue: any AuthSessionStatusProtocol, newValue: any AuthSessionStatusProtocol)

    /// A session operation failed.
    /// - Parameter error: The ``AuthSessionError`` describing the failure.
    ///
    /// Mirrors ``AuthSessionDelegate/authentication(_:didFailWith:for:)``.
    case failure(error: AuthSessionError)

    /// The session's user data changed without a status transition.
    ///
    /// Mirrors ``AuthSessionDelegate/authentication(_:didUpdate:for:)``.
    case userUpdate
}

