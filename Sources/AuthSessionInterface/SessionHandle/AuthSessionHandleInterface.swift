//
//  AuthSessionHandleInterface.swift
//  AuthSessionKit
//
//  Created by kavi gevariya on 25/04/26.
//

import Foundation
import MultiCastDelegate



/// A type that controls session-level settings and security policies.
///
/// A session handle wraps an ``AuthSessionProviderInterface`` conformer,
/// exposing the current session and optional security features such as
/// biometric authentication.
///
/// The associated ``AuthSessionProvider`` type ties the handle to a
/// specific provider, giving type-safe access to its ``AuthSessionInterface``
/// session.
public protocol AuthSessionHandleInterface: DelegateMultiCasting, Sendable where Delegate == any AuthSessionDelegate {

    /// The concrete session provider type this handle manages.
    associatedtype AuthSessionProvider where AuthSessionProvider: AuthSessionProviderInterface

    /// The underlying session provider.
    var sessionProvider: AuthSessionProvider { get }

    /// The provider's current session, or `nil` if no session is active.
    var session: AuthSessionProvider.AuthSession? { get }
    
    associatedtype SessionStatus: AuthSessionStatusInterface
    var sessionStatus: SessionStatus { get }

    /// A Boolean value indicating whether a biometric authentication prompt is currently displayed.
    var isBiometricAuthenticationInProcess: Bool { get }

    /// A Boolean value indicating whether the user must authenticate manually (e.g., via a login screen) before the session can be used.
    var isManualAuthenticationRequired: Bool { get }

    /// Creates a new session handle backed by the given session provider.
    /// - Parameter sessionProvider: The provider that manages the underlying authentication session.
    init(sessionProvider: AuthSessionProvider)
}


extension AuthSessionHandleInterface {
    
    /// A Boolean value that indicates whether biometric authentication (Face ID / Touch ID) is enabled.
    var isBioMetricAuthenticationEnabled: Bool {
        return sessionProvider.isBioMetricAuthenticationEnabled
    }
    
    /// Enables or disables biometric authentication for the session.
    /// - Parameter isEnabled: Pass `true` to require biometric verification; `false` to disable it.
    func setBioMetricAuthentication(_ isEnabled: Bool) {
        sessionProvider.setBioMetricAuthentication(isEnabled)
    }
}
