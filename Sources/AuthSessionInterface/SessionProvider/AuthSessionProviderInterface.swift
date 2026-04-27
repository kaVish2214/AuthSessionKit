//
//  AuthSessionProviderInterface.swift
//  AuthSessionKit
//
//  Created by kavi gevariya on 25/04/26.
//

import Foundation
import BiometricAuthInterface


/// A type that vends and manages authentication sessions.
///
/// Conforming types are responsible for creating, refreshing, and
/// invalidating sessions. Call ``initializeSessionProvider(for:)`` after
/// construction to wire up an ``AuthSessionEventProxy`` that receives
/// lifecycle events (e.g., fetch, success, failure).
///
/// The associated ``AuthSession`` type defines the concrete session model
/// returned by the provider.
public protocol AuthSessionProviderInterface: Sendable, BiometricAuthenticationRequestor {

    /// The concrete session type this provider manages.
    associatedtype AuthSession where AuthSession: AuthSessionInterface

    /// The current session, or `nil` if no session has been established yet.
    var session: AuthSession? { get }
    
    
    /// A Boolean value indicating whether biometric authentication (Face ID / Touch ID) is enabled for this provider.
    var isBioMetricAuthenticationEnabled: Bool { get }

    /// A Boolean value indicating whether the provider supports local session validation (e.g., expiry checks) on `didBecomeActive`.
    var allowsLocalSessionValidation: Bool { get }

    /// A Boolean value indicating whether the provider automatically refreshes the session token before it expires.
    var isSessionAutoRefreshEnabled: Bool { get }

    /// Initializes the provider's internal session-fetching logic with the given event proxy.
    ///
    /// Call this once after creating the provider. The proxy will receive
    /// ``AuthSessionEvent`` callbacks as the session is fetched, refreshed, or fails.
    /// - Parameter eventProxy: The proxy that receives and forwards session lifecycle events.
    func initializeSessionProvider(for eventProxy: any AuthSessionEventProxy)

    /// Enables or disables biometric authentication for this provider.
    /// - Parameter isEnabled: Pass `true` to enable biometric verification; `false` to disable it.
    func setBioMetricAuthentication(_ isEnabled: Bool)

    /// Signs the user out, optionally providing the error that triggered the sign-out.
    /// - Parameter error: The error that caused the sign-out, or `nil` for a voluntary sign-out.
    /// - Throws: An error if the sign-out operation fails at the provider level.
    func signout(with error: Error?) throws
    
    /// Whether a biometric authentication failure should trigger a full sign-out.
    ///
    /// Return `true` (the default) to sign the user out on failure.
    /// Return `false` to keep the session active and let delegates handle the
    /// error — useful for retry or fallback-to-PIN flows.
    /// - Parameter error: The biometric error that occurred.
    func allowsSessionSigningOutOnBiometricAuthenticationFailure(with error: BiometricAuthenticationError) -> Bool
    
}

// MARK: - Defaults

extension AuthSessionProviderInterface {

    /// Defaults to `true` — providers validate sessions locally unless overridden.
    public var allowsLocalSessionValidation: Bool {
        return true
    }

    /// Defaults to `false` — providers do not auto-refresh unless overridden.
    public var isSessionAutoRefreshEnabled: Bool {
        false
    }
    
    /// Defaults to `true` — biometric failure triggers sign-out unless overridden.
    public func allowsSessionSigningOutOnBiometricAuthenticationFailure(with error: BiometricAuthenticationError) -> Bool {
        return true
    }
}

extension AuthSessionProviderInterface {

    /// Convenience for signing out without a triggering error.
    public func signout() throws {
        try self.signout(with: nil)
    }
}
