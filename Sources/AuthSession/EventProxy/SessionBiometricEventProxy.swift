//
//  SessionBiometricEventProxy.swift
//  AuthSessionKit
//
//  Created by kavi gevariya on 25/04/26.
//

import UIKit
import AuthSessionInterface


/// A type that handles biometric authentication outcomes on behalf of the session handle.
///
/// ``SessionHandleEventProxy`` holds a weak reference to a conformer and forwards
/// biometric success/failure callbacks through it, keeping the handle decoupled
/// from ``BiometricAuthenticationDelegator``.
protocol SessionBiometricEventProxy: NSObjectProtocol, Sendable {

    /// The event proxy used to route errors back to the session event system.
    var sessionEventProxy: (any AuthSessionEventProxy)? { get }

    /// Transitions the session to the given status (e.g., `.signedIn` on biometric success).
    func set(sessionStatus status: AuthSessionStatus)

    /// Forwards a biometric-triggered sign-out to the session provider.
    /// - Parameter error: The error that caused the sign-out, or `nil`.
    /// - Throws: Rethrows any error from the provider's `signout(with:)`.
    func biometricAuthProxyRequestSignout(with error: Error?) throws
}
